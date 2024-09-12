root = global ? window

# Useage of etmodel jquery plugin:
#
#      $(document).etmodel({})
#
# There can be individual sections, each having it's own scenario that
# updates individually
#
#      $('.etmodel-scenario').etmodel({})
#
# The plugin will search for the following tags:
#
# Settings:
#
#      <input data-etm-area-code="nl">
#      <input data-etm-end-year="2050">
#
# Inputs:
#
#      <input data-etm-input="some_input_key" value="0.0">
#
# The model will automatically update when the inputs are changed. Define a start-value
# with the value tag. Otherwise the default start value provided by us, will be used.
#
# Outputs/Queries:
#
#      <span data-etm-output="some_input_key">this will be replaced</span>
#
#      Show the present/future or the delta in percent:
#      <span ... data-etm-period="present">
#      <span ... data-etm-period="future">
#      <span ... data-etm-period="delta_percent">
#
#      Round the numbers (default: 1):
#      <span ... data-etm-round="2">
#
#
if ($?) # makes testing easier.
  $.fn.extend
    etmodel: (options = {}) ->
      self = $.fn.etmodel
      # opts = $.extend {}, self.default_options, options
      scenarios = []
      $(this).each (i, el) ->
        etm = new Etmodel(el, options)
        scenarios.push etm
        etm.update()
        etm.tagInputs()
      scenarios

else
  console?.warn?("jQuery not yet included")


# ---- Etmodel ----------------------------------------------------------------

class root.Etmodel
  # Initializes an etmodel scenario inside the @base
  #
  #     etm = new Etmodel("body")
  #     etm.update()
  #
  # There can be multiple different etmodel scenarios in one given page. They
  # will be updated separately
  #
  #     etm = new Etmodel(".etmodel-scenario")
  #     etm.update()
  #
  constructor: (base, options = {}) ->
    @base = $(base)

    @scenario =
      end_year:  $('input[data-etm-end-year]',  @base).attr('data-etm-end-year')  || 2050
      area_code: $('input[data-etm-area-code]', @base).attr('data-etm-area-code') || 'nl'

    @api     = new ApiGateway($.extend @scenario, options)
    @inputs  = $('[data-etm-input]',  @base).bind('change', => @update())
    @outputs = $('[data-etm-output]', @base)
    @outputs.each (i,el) -> $(el).html('...')
    @charts = []
    if Chart?
      @charts.push(new Chart(c)) for c in $('[data-etm-chart-type]', @base)

  update: ->
    inputs = {}
    @inputs.each (i, el) ->
      inputs[ $(el).attr('data-etm-input') ] = $(el).val()

    query_keys = []
    @outputs.each (i, el) -> query_keys.push($(el).attr('data-etm-output'))

    $.merge(query_keys, chart.gqueries()) for chart in @charts

    @api.update({
      inputs:  inputs,
      queries: $.unique(query_keys),
      success: @handle_result
    })

  tagInputs: ->
    @api.userValues({
      success: (inputs) =>
        for input in @inputs
          # Set the input type directly, seen as jQuery throws an exception
          # when trying to change the type.
          input.type = 'number'

          # Cycle through the inputs list and set min and max properties.
          $input = $(input)
          key    = $input.data('etm-input')

          $input.attr({
            min: inputs[key].min,
            max: inputs[key].max
          })

          $input.quinn() if $input.data('etm-type') is 'quinn'
    })

  # Updates data-etm-output elements with the results from the api call
  handle_result: (data) =>
    for own key, result of data.results
      $("[data-etm-output=#{key}]", @base).each (i,el) ->
        callback = $(el).attr('data-etm-update') || 'format'
        Etmodel.Callbacks[callback](el, result)
    # charts need also scenario data, so they receive the entire response
    chart.refresh(data) for chart in @charts

class Etmodel.Callbacks

  @format: (element, result) ->
    format_str = $(element).attr('data-etm-format') || 'future;round'
    result     = new Etmodel.ResultFormatter(result, format_str).value()
    $(element).html(result)

# ---- ResultFormatter --------------------------------------------------------


class Etmodel.ResultFormatter
  constructor: (@result, @format_string="future;round") ->

  value: ->
    result = @result
    for formatter in @format_string.split(";")
      [method, args] = formatter.split(":")
      params = [result].concat args
      result = this[method].apply(null, params)
    result

  valueOf: ->
    value()

  toString: ->
    "#{value()}"

  # Expect an API result in the form of a hash: {present: 45, future: 48, unit: 'bln_euro'}
  future: (result)  -> result.future

  present: (result) -> result.present

  delta: (result)   ->
    f = result.future
    p = result.present
    return 0.0 if f is 0 && p is 0
    f / p - 1.0

  percent: (number) -> number * 100

  round: (number, precision) ->
    precision ||= 1
    precision   = parseInt(precision)
    multiplier  = Math.pow(10, precision);
    if precision > 0
      (Math.round(number * multiplier) / multiplier)
    else if precision is 0
      Math.round(number)
    else
      Math.round(number * multiplier) / multiplier


# ---- ApiGateway -------------------------------------------------------------


# ApiGateway connects to the etengine gateway and does all the necessary checks.
#
# @example:
#
#     api = new ApiGateway()
#     api.update
#       inputs:  {households_number_of_inhabitants: -1.5}
#       queries: ['dashboard_total_costs']
#       success: (result) ->
#         console.log(result.queries.dashboard_total_costs.future)
#       error: -> alert("error")
#
# @example configuration and before/afterLoading callbacks:
#
#     api = new ApiGateway
#        scenario_id: 323231
#        beforeLoading: -> console.log('before')
#        afterLoading:  -> console.log('after')
#
# @example api.ensure_id()
#
#     api = new ApiGateway()
#     api.scenario_id # => null
#     api.ensure_id().done (id) -> id # => 32311
#     api.scenario_id
#
#
class root.ApiGateway
  PATH = null

  VERSION = '0.3'

  # The result hash a callback can expect
  # @example
  #     success = (data) -> $.extend DEFAULT_CALLBACK_ARGS, data
  DEFAULT_CALLBACK_ARGS = {results: {}, inputs: {}, scenario: {}}


  # Queue holds api_calls. Currently we simply check whether there are
  # elements in the queue when calling hideLoading().
  @queue: []

  # If CORS is not enabled an API proxy is required
  default_options:
    # api ajax attributes
    api_path:       'http://www.et-engine.com'
    api_proxy_path: '/ete'
    offline:        false
    # callbacks
    beforeLoading:  ->
    afterLoading:   ->
    # TODO: requestTimeout: ->
    defaultErrorHandler: ->
      if console?
        console.log("ApiGateway.update Error:", arguments)

  # @example
  #     new ApiGateway({scenario_id: 2991})
  #
  constructor: (opts) ->
    @__apply_settings__(opts)
    @setPath(@opts.api_path, @opts.api_proxy_path, @opts.offline)


  # Update settings in local instance. Does not persist.
  # Use changeScenario instead.
  #
  # @example updating scenario id
  #      api.__apply_settings__({scenario_id: 1})
  #      api.__apply_settings__({id: 2})
  #
  __apply_settings__: (opts) ->
    @opts        = $.extend {}, @default_options, opts
    @scenario    = @__pick_scenario_settings__(@opts)
    @scenario_id = @opts.scenario_id || @opts.id || null

  # Returns the headers to be sent with each request to the Engine.
  request_headers: ->
    headers = { "X-Api-Agent": "jQuery.etmodel #{VERSION}" }

    if @opts.access_token
      headers.Authorization = "Bearer #{@opts.access_token}"

    headers

  # Requests an empty scenario and assigns @scenario_id
  # Wrap things that need a scenario_id inside the ready block.
  #
  # @example Useage
  #   @ensure_id().done (id) -> console.log(id)
  #
  ensure_id: ->
    return @deferred_scenario_id if @deferred_scenario_id
    # scenario_id available?
    if id = @scenario_id
      # @debug "Scenario URL: #{@scenario_url()}"
      # encapsulate in a deferred object, so we can attach callbacks
      @deferred_scenario_id = $.Deferred().resolve(id)
    else
      # or fetch a new one?
      @deferred_scenario_id = $.ajax(
        url:  @path "scenarios"
        type: 'POST'
        data: { scenario : @scenario }
        error: @opts.defaultErrorHandler
        headers: @request_headers()
      ).pipe (data) ->
        if typeof data is 'string' # FF does not parse data...
          data = $.parseJSON(data)
        data.id

      # When we first get the scenario id let's save it locally
      @deferred_scenario_id.done (id) =>
        @scenario_id = id
        # @debug "Scenario URL: #{@scenario_url()}"

    # return the deferred object, so we can attach callbacks as needed
    @deferred_scenario_id

  # Creates a new scenario if no @scenario_id is set, or resumes an existing
  # scenario if it is.
  #
  # The callback will yield the data returned by ETEngine.
  create_or_resume_scenario: ->
    if @deferred_scenario
      @deferred_scenario
    else
      @deferred_scenario = if @scenario_id
        @resume_scenario()
      else
        @create_scenario()

      @deferred_scenario.done((data) => @__apply_settings__(data))

  # Creates a new scenario on ETEngine using the ApiGateway settings.
  #
  # The callback will yield the data returned by ETEngine.
  create_scenario: ->
    jQuery.ajax
      url: @path "scenarios"
      type: 'POST'
      error: @opts.defaultErrorHandler
      headers: @request_headers()
      data:
        include_inputs: true
        scenario: @scenario

  # Resumes an existing scenario on ETEngine.
  #
  # The callback will yield the data returned by ETEngine.
  resume_scenario: ->
    jQuery.ajax
      url: @path "scenarios/#{ @scenario_id }"
      type: 'GET'
      error: @opts.defaultErrorHandler
      headers: @request_headers()
      data:
        include_inputs: true

  # It clones the current scenario with the given attributes.
  #
  # @example
  #     api.scenario_id          # => 20121
  #     api.changeScenario
  #       attributes: {end_year: 2050}
  #       success: -> alert('changed')
  #     # The settings hash will change too.
  #     api.settings.end_year    # => 2050
  #     api.scenario_id          # => 20122
  #
  changeScenario: ({attributes, success, error}) ->
    @__apply_settings__(attributes) # scenario_id will also change.

    success_callback = (data, textStatus, jqXHR) =>
      args = $.extend(DEFAULT_CALLBACK_ARGS, {scenario: data})
      @__apply_settings__(args.scenario)           # scenario_id changed.
      success(args, data, textStatus, jqXHR)  # The supplied callback.

    params = {scenario: @scenario}
    @ensure_id().done (id) =>
      url = @path "scenarios"

      @__call_api__(url, params, success_callback, error, {type: 'POST'} )


  # resets all slider settings also the ones from a preset scenario.
  # keeps area_code, end_year, use_fce and peak_load settings
  #
  resetScenario: ({success, error}) ->
    success_callback = (data, textStatus, jqXHR) ->
      args = $.extend(DEFAULT_CALLBACK_ARGS, data)
      success(args, data, textStatus, jqXHR)

    @ensure_id().done (id) =>
      url = @path "scenarios/#{@scenario_id}"
      @__call_api__(url, {reset: 1}, success_callback, error, {type: 'PUT'} )


  # Loads scenarios/../inputs.json that contains attributes for the inputs.
  #
  user_values: ({success, error, extras, cache}) =>
    headers = cache ? @request_headers() : $.extend(@request_headers(), { "cache-control": "no-cache, no-store, max-age=0, must-revalidate" })
    @ensure_id().done =>
      $.ajax
        url: @path("scenarios/#{@scenario_id}/inputs.json")
        cache: cache
        data: { include_extras: extras, time: new Date.getTime() }
        headers: headers
        success : success
        error: error
        dataType: 'json'

  userValues: @prototype.user_values

  # Currently ajax calls are queued with a simple $.ajaxQueue.
  # TODO: when there's multiple requests in the queue they should be reduced
  #   to one call, by merging inputs and queries. But only if the callbacks
  #   are the same too.
  #
  # inputs    - a hash of input keys and values (defined by user)
  # queries   - an array of gquery keys that gets returned by the api.
  # success   - callback for successful api call
  # error     - callback for errornous api call
  # reset     - set to true to reset values on the engine side
  #
  # @example success callback:
  #     api.update {success: (data) -> data.results.dashboard_total_costs.future }
  #     api.update {success: ({results, settings, inputs}) -> ... }
  #     # The original parameters are appended:
  #     api.update {success: (data, response, textStatus, jqXHR) -> ... }
  #
  #     handle_api_result: ({results, settings, inputs}, response, textStatus, jqXHR) =>
  #
  # update is the default api request that sets new inputs, updates settings
  # and returns results of queries)
  #
  update: ({inputs, queries, success, error, reset, settings}) ->
    @ensure_id().done (id) =>
      error ||= @opts.defaultErrorHandler

      params =
        autobalance: true
        scenario:
          user_values: inputs

      # omit empty key => null pairs
      params.gqueries = queries if queries?
      params.reset = reset if reset?

      if settings?
        for key, value of @__pick_scenario_settings__(settings)
          params.scenario[key] = value

      url  = @path "scenarios/#{ @scenario_id }"

      # we modifiy the success_callback here and not in __call_api__
      # because I want __call_api__ to be generic. the parsing of results
      # only is needed in this specific request type.
      success_callback = (data, textStatus, jqXHR) =>
        args = @__parse_success__(data, textStatus, jqXHR)
        success(args, data, textStatus, jqXHR)

      @__call_api__(url, params, success_callback, error)


  # maps the results from a update call and to the default argument.
  #
  # {
  #   results: {query_key: {present: 12, future: 14, etc}}
  #   inputs:  {123: 0.4}
  #   scenario: {...}
  # }
  __parse_success__: (data, textStatus, jqXHR) ->
    mapping =
      results:  data.gqueries
      inputs:   data.scenario.user_values || {}
      scenario: data.scenario

    $.extend DEFAULT_CALLBACK_ARGS, mapping


  # __call_api should be a general
  #
  # params    - the params sent to the server
  # success   - callback for successful api call
  # error     - callback for errornous api call
  __call_api__: (url, params, success, error, ajaxOptions = {}) ->
    opts = $.extend {
      url:       url
      data:      params
      type:      'PUT'
      dataType:  'json'
      headers: @request_headers()
    }, ajaxOptions


    @opts.beforeLoading()
    ApiGateway.queue.push('call_api')

    afterLoading = @opts.afterLoading
    jQuery.ajaxQueue(opts)
      .done (data, textStatus, jqXHR) ->
        success(data, textStatus, jqXHR)
      .fail (jqXHR, textStatus, err) ->
        # TODO: error should return an array of error messages
        error(jqXHR, textStatus, err)
      .always () ->
        ApiGateway.queue.pop()
        afterLoading() if ApiGateway.queue.length == 0


  # extracts only keys relevant for settings from hsh
  __pick_scenario_settings__: (hsh) ->
    result = {}
    for key in ['area_code', 'end_year', 'preset_id', 'use_fce', 'source', 'scale']
      result[key] = hsh[key] if hsh[key]?

    if hsh.preset_scenario_id
      result.scenario_id = hsh.preset_scenario_id

    result

  # Sets the path used when sending API requests to ETEngine. Self-destructs
  # after the first time it is called.
  # This hard-coded stuff from ETFlex should better be removed
  #
  setPath: (path, proxy_path, offline = false) ->
    ios4 = navigator.userAgent?.match(/CPU (iPhone )?OS 4_/)
    #  cors | ios4 | offl
    #   1       0      0   # => ok
    #   1       1      0   # => /ete
    #   1       0      1   # => /ete
    #   0      0/1    0/1  # => /ete
    #
    PATH = if jQuery.support.cors and not ios4 and not offline
      # remove trailing slash "et-engine.com/"
      path = path.replace(/\/$/, '')
    else
      proxy_path

    @isBeta  = path.match(/^https?:\/\/beta\./)?
    @setPath = (->)

  # Creates a path for an API request. Prevents malicious users messing with the
  # API variable.
  #
  # path - The URL path; appended to the API path.
  #
  path: (suffix) -> "#{ PATH }/api/v3/#{ suffix }"


if typeof(exports) != 'undefined'
  exports.Etmodel    = Etmodel
  exports.ApiGateway = ApiGateway
