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
if ($?)
  $.fn.extend
    etmodel: (options = {}) ->
      self = $.fn.etmodel
      # opts = $.extend {}, self.default_options, options
      $(this).each (i, el) ->
        etm = new Etmodel(el, options)
        etm.update()

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

    @settings =
      end_year:  $('input[data-etm-end-year]',  @base).attr('data-etm-end-year')   || 2050
      area_code: $('input[data-etm-area-code]', @base).attr('data-etm-area-code') || 'nl'

    @api     = new ApiGateway(@settings)
    @inputs  = $('[data-etm-input]',  @base).bind('change', => @update())
    @outputs = $('[data-etm-output]', @base).each (i,el) ->
      $(el).html('...')

  update: ->
    inputs = {}
    @inputs.each (i, el) ->
      inputs[ $(el).attr('data-etm-input') ] = $(el).val()

    query_keys = []
    @outputs.each (i, el) -> query_keys.push($(el).attr('data-etm-output'))

    @api.update({
      inputs:  inputs,
      queries: $.unique(query_keys),
      success: @handle_result
    })

  # Updates data-etm-output elements with the results from the api call
  handle_result: ({results}) =>
    for own key, values of results
      $("[data-etm-output=#{key}]", @base).each (i,el) ->
        format_str = $(el).attr('data-etm-format') || 'future;round'
        result     = new Etmodel.ResultFormatter(values, format_str).value()
        $(el).html(result)

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
class @ApiGateway
  PATH = null
  VERSION = '0.1'

  # Queue holds api_calls. Currently we simply check whether there are
  # elements in the queue when calling hideLoading().
  @queue: []

  # scenario_id used for etengine api. if null constructor loads
  # a new scenario.
  scenario_id: null

  # Using the beta API?
  isBeta: false

  default_options:
    # api ajax attributes
    api_path:    'http://beta.et-engine.com'
    offline:     false
    log:         true
    # callbacks
    beforeLoading:  ->
    afterLoading:   ->
    # TODO: requestTimeout: ->
    defaultErrorHandler: ->
      console.log("ApiGateway.update Error:")
      console.log(arguments)


  constructor: (opts) ->
    @opts   = $.extend {}, @default_options, opts
    @settings = @pickSettings(@opts)

    @scenario_id = @opts.scenario_id || null
    @setPath(@opts.api_path, @opts.offline)

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
        data: {scenario : @settings }
        timeout: 10000
        error: @opts.defaultErrorHandler
      ).pipe (d) -> d.id
      # When we first get the scenario id let's save it locally
      @deferred_scenario_id.done (id) =>
        @scenario_id = id
        # @debug "Scenario URL: #{@scenario_url()}"

    # return the deferred object, so we can attach callbacks as needed
    @deferred_scenario_id

  changeScenario: ({attributes, success, error}) ->
    @settings = $.extend @settings, @pickSettings(attributes)
    # @ensure_id().done =>
    #   url = @path "scenarios"
    #   @__call_api__(url, {scenario: @settings}, ->, ->, {type: 'POST'} )

  # resets all slider settings also the ones from a preset scenario.
  # keeps area_code, end_year, use_fce and peak_load settings
  resetScenario: ->

  # Currently ajax calls are queued with a simple $.ajaxQueue.
  # TODO: when there's multiple requests in the queue they should be reduced
  #   to one call, by merging inputs and queries. But only if the callbacks
  #   are the same too.
  #
  # inputs    - a hash of input keys and values (defined by user)
  # queries   - an array of gquery keys that gets returned by the api.
  # success   - callback for successful api call
  # error     - callback for errornous api call
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
  update: ({inputs, queries, success, error, settings}) ->
    @ensure_id().done =>
      error ||= @opts.defaultErrorHandler

      params =
        autobalance: true
        scenario:
          user_values: inputs
      # omit empty key => null pairs
      params.gqueries = queries  if queries?
      params.settings = settings if settings?

      url  = @path "scenarios/#{ @scenario_id }"

      # we modifiy the success_callback here and not in __call_api__
      # because I want __call_api__ to be generic. the parsing of results
      # only is needed in this specific request type.
      success_callback = (data, textStatus, jqXHR) =>
        parsed_results = @__parse_success__(data, textStatus, jqXHR)
        success(parsed_results, data, textStatus, jqXHR)

      @__call_api__(url, params, success_callback, error)

  # Loads scenarios/../inputs.json that contains attributes for
  # the inputs.
  user_values: ({success, error}) =>
    @ensure_id().done =>
      $.ajax
        url: @path("scenarios/#{@scenario_id}/inputs.json")
        success : success
        dataType: 'json'
        timeout:  15000

  # extracts the results and returns a standardised hash.
  #
  # {
  #   results: {query_key: {present: 12, future: 14, etc}}
  #   inputs:  {123: 0.4}
  #   settings: {...}
  # }
  __parse_success__: (data, textStatus, jqXHR) ->
    result =
      results:  {}
      inputs:   data.settings?.user_values
      settings: data.settings || {}

    for own key, values of data.gqueries
      result.results[key] = values

    result


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
      timeout:   10000
      headers:   {
        'X-Api-Agent': "jQuery.etmodel #{VERSION}"
      }
    }, ajaxOptions


    @opts.beforeLoading()
    ApiGateway.queue.push('call_api')

    afterLoading = @opts.afterLoading
    jQuery.ajaxQueue(opts)
      .done (data, textStatus, jqXHR) ->
        ApiGateway.queue.pop()
        afterLoading() if ApiGateway.queue.length == 0
        success(data, textStatus, jqXHR)
      .fail (jqXHR, textStatus, err) ->
        ApiGateway.queue.pop()
        afterLoading() if ApiGateway.queue.length == 0
        error(jqXHR, textStatus, err)

  # extracts only keys relevant for settings from hsh
  pickSettings: (hsh) ->
    result = {}
    for key in ['area_code', 'end_year', 'preset_id', 'use_fce']
      result[key] = hsh[key]
    result

  # Sets the path used when sending API requests to ETEngine. Self-destructs
  # after the first time it is called.
  #
  setPath: (path, offline = false) ->
    ios4 = navigator.userAgent?.match(/CPU (iPhone )?OS 4_/)
    PATH = if jQuery.support.cors and not ios4 and not offline
      path
    else
      '/ete'

    @isBeta  = path.match(/^https?:\/\/beta\./)?
    @setPath = (->)

  # Creates a path for an API request. Prevents malicious users messing with the
  # API variable.
  #
  # path - The URL path; appended to the API path.
  #
  path: (suffix) -> "#{ PATH }/api/v3/#{ suffix }"


if typeof(exports) != 'undefined' then exports.Etmodel = Etmodel