/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS203: Remove `|| {}` from converted for-own loops
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
const root = typeof global !== "undefined" && global !== null ? global : window;

// Useage of etmodel jquery plugin:
//
//      $(document).etmodel({})
//
// There can be individual sections, each having it's own scenario that
// updates individually
//
//      $('.etmodel-scenario').etmodel({})
//
// The plugin will search for the following tags:
//
// Settings:
//
//      <input data-etm-area-code="nl">
//      <input data-etm-end-year="2050">
//
// Inputs:
//
//      <input data-etm-input="some_input_key" value="0.0">
//
// The model will automatically update when the inputs are changed. Define a start-value
// with the value tag. Otherwise the default start value provided by us, will be used.
//
// Outputs/Queries:
//
//      <span data-etm-output="some_input_key">this will be replaced</span>
//
//      Show the present/future or the delta in percent:
//      <span ... data-etm-period="present">
//      <span ... data-etm-period="future">
//      <span ... data-etm-period="delta_percent">
//
//      Round the numbers (default: 1):
//      <span ... data-etm-round="2">
//
//
if (typeof $ !== "undefined" && $ !== null) {
  // makes testing easier.
  $.fn.extend({
    etmodel(options) {
      if (options == null) {
        options = {};
      }
      const self = $.fn.etmodel;
      // opts = $.extend {}, self.default_options, options
      const scenarios = [];
      $(this).each(function (i, el) {
        const etm = new Etmodel(el, options);
        scenarios.push(etm);
        etm.update();
        return etm.tagInputs();
      });
      return scenarios;
    },
  });
} else {
  console?.warn?.("jQuery not yet included");
}

// ---- Etmodel ----------------------------------------------------------------

root.Etmodel = class Etmodel {
  // Initializes an etmodel scenario inside the @base
  //
  //     etm = new Etmodel("body")
  //     etm.update()
  //
  // There can be multiple different etmodel scenarios in one given page. They
  // will be updated separately
  //
  //     etm = new Etmodel(".etmodel-scenario")
  //     etm.update()
  //
  constructor(base, options) {
    this.handle_result = this.handle_result.bind(this);
    if (options == null) {
      options = {};
    }
    this.base = $(base);

    this.scenario = {
      end_year: $("input[data-etm-end-year]", this.base).attr("data-etm-end-year") || 2050,
      area_code: $("input[data-etm-area-code]", this.base).attr("data-etm-area-code") || "nl",
    };

    this.api = new ApiGateway($.extend(this.scenario, options));
    this.inputs = $("[data-etm-input]", this.base).bind("change", () => this.update());
    this.outputs = $("[data-etm-output]", this.base);
    this.outputs.each((i, el) => $(el).html("..."));
    this.charts = [];
    if (typeof Chart !== "undefined" && Chart !== null) {
      for (let c of Array.from($("[data-etm-chart-type]", this.base))) {
        this.charts.push(new Chart(c));
      }
    }
  }

  update() {
    const inputs = {};
    this.inputs.each((i, el) => (inputs[$(el).attr("data-etm-input")] = $(el).val()));

    const query_keys = [];
    this.outputs.each((i, el) => query_keys.push($(el).attr("data-etm-output")));

    for (let chart of Array.from(this.charts)) {
      $.merge(query_keys, chart.gqueries());
    }

    return this.api.update({
      inputs,
      queries: $.unique(query_keys),
      success: this.handle_result,
    });
  }

  tagInputs() {
    return this.api.userValues({
      success: (inputs) => {
        return (() => {
          const result = [];
          for (let input of Array.from(this.inputs)) {
            // Set the input type directly, seen as jQuery throws an exception
            // when trying to change the type.
            input.type = "number";

            // Cycle through the inputs list and set min and max properties.
            const $input = $(input);
            const key = $input.data("etm-input");

            $input.attr({
              min: inputs[key].min,
              max: inputs[key].max,
            });

            if ($input.data("etm-type") === "quinn") {
              result.push($input.quinn());
            } else {
              result.push(undefined);
            }
          }
          return result;
        })();
      },
    });
  }

  // Updates data-etm-output elements with the results from the api call
  handle_result(data) {
    for (let key of Object.keys(data.results || {})) {
      var result = data.results[key];
      $(`[data-etm-output=${key}]`, this.base).each(function (i, el) {
        const callback = $(el).attr("data-etm-update") || "format";
        return Etmodel.Callbacks[callback](el, result);
      });
    }
    // charts need also scenario data, so they receive the entire response
    return Array.from(this.charts).map((chart) => chart.refresh(data));
  }
};

Etmodel.Callbacks = class Callbacks {
  static format(element, result) {
    const format_str = $(element).attr("data-etm-format") || "future;round";
    result = new Etmodel.ResultFormatter(result, format_str).value();
    return $(element).html(result);
  }
};

// ---- ResultFormatter --------------------------------------------------------

Etmodel.ResultFormatter = class ResultFormatter {
  constructor(result, format_string) {
    this.result = result;
    if (format_string == null) {
      format_string = "future;round";
    }
    this.format_string = format_string;
  }

  value() {
    let { result } = this;
    for (let formatter of Array.from(this.format_string.split(";"))) {
      const [method, args] = Array.from(formatter.split(":"));
      const params = [result].concat(args);
      result = this[method].apply(null, params);
    }
    return result;
  }

  valueOf() {
    return value();
  }

  toString() {
    return `${value()}`;
  }

  // Expect an API result in the form of a hash: {present: 45, future: 48, unit: 'bln_euro'}
  future(result) {
    return result.future;
  }

  present(result) {
    return result.present;
  }

  delta(result) {
    const f = result.future;
    const p = result.present;
    if (f === 0 && p === 0) {
      return 0.0;
    }
    return f / p - 1.0;
  }

  percent(number) {
    return number * 100;
  }

  round(number, precision) {
    if (!precision) {
      precision = 1;
    }
    precision = parseInt(precision);
    const multiplier = Math.pow(10, precision);
    if (precision > 0) {
      return Math.round(number * multiplier) / multiplier;
    } else if (precision === 0) {
      return Math.round(number);
    } else {
      return Math.round(number * multiplier) / multiplier;
    }
  }
};

// ---- ApiGateway -------------------------------------------------------------

// ApiGateway connects to the etengine gateway and does all the necessary checks.
//
// @example:
//
//     api = new ApiGateway()
//     api.update
//       inputs:  {households_number_of_inhabitants: -1.5}
//       queries: ['dashboard_total_costs']
//       success: (result) ->
//         console.log(result.queries.dashboard_total_costs.future)
//       error: -> alert("error")
//
// @example configuration and before/afterLoading callbacks:
//
//     api = new ApiGateway
//        scenario_id: 323231
//        beforeLoading: -> console.log('before')
//        afterLoading:  -> console.log('after')
//
// @example api.ensure_id()
//
//     api = new ApiGateway()
//     api.scenario_id # => null
//     api.ensure_id().done (id) -> id # => 32311
//     api.scenario_id
//
//
(function () {
  let PATH = undefined;
  let VERSION = undefined;
  let DEFAULT_CALLBACK_ARGS = undefined;
  const Cls = (root.ApiGateway = class ApiGateway {
    static initClass() {
      PATH = null;

      VERSION = "0.3";

      // The result hash a callback can expect
      // @example
      //     success = (data) -> $.extend DEFAULT_CALLBACK_ARGS, data
      DEFAULT_CALLBACK_ARGS = { results: {}, inputs: {}, scenario: {} };

      // Queue holds api_calls. Currently we simply check whether there are
      // elements in the queue when calling hideLoading().
      this.queue = [];

      // If CORS is not enabled an API proxy is required
      this.prototype.default_options = {
        // api ajax attributes
        api_path: "http://www.et-engine.com",
        api_proxy_path: "/ete",
        offline: false,
        // callbacks
        beforeLoading() {},
        afterLoading() {},
        // TODO: requestTimeout: ->
        defaultErrorHandler() {
          if (typeof console !== "undefined" && console !== null) {
            return console.log("ApiGateway.update Error:", arguments);
          }
        },
      };

      this.prototype.userValues = this.prototype.user_values;
    }

    // @example
    //     new ApiGateway({scenario_id: 2991})
    //
    constructor(opts) {
      this.user_values = this.user_values.bind(this);
      this.__apply_settings__(opts);
      this.setPath(this.opts.api_path, this.opts.api_proxy_path, this.opts.offline);
    }

    // Update settings in local instance. Does not persist.
    // Use changeScenario instead.
    //
    // @example updating scenario id
    //      api.__apply_settings__({scenario_id: 1})
    //      api.__apply_settings__({id: 2})
    //
    __apply_settings__(opts) {
      this.opts = $.extend({}, this.default_options, opts);
      this.scenario = this.__pick_scenario_settings__(this.opts);
      return (this.scenario_id = this.opts.scenario_id || this.opts.id || null);
    }

    // Returns the headers to be sent with each request to the Engine.
    request_headers() {
      const headers = { "X-Api-Agent": `jQuery.etmodel ${VERSION}` };

      if (this.opts.access_token) {
        headers.Authorization = `Bearer ${this.opts.access_token}`;
      }

      return headers;
    }

    // Requests an empty scenario and assigns @scenario_id
    // Wrap things that need a scenario_id inside the ready block.
    //
    // @example Useage
    //   @ensure_id().done (id) -> console.log(id)
    //
    ensure_id() {
      let id;
      if (this.deferred_scenario_id) {
        return this.deferred_scenario_id;
      }
      // scenario_id available?
      if ((id = this.scenario_id)) {
        // @debug "Scenario URL: #{@scenario_url()}"
        // encapsulate in a deferred object, so we can attach callbacks
        this.deferred_scenario_id = $.Deferred().resolve(id);
      } else {
        // or fetch a new one?
        this.deferred_scenario_id = $.ajax({
          url: this.path("scenarios"),
          type: "POST",
          data: { scenario: this.scenario },
          error: this.opts.defaultErrorHandler,
          headers: this.request_headers(),
        }).pipe(function (data) {
          if (typeof data === "string") {
            // FF does not parse data...
            data = $.parseJSON(data);
          }
          return data.id;
        });

        // When we first get the scenario id let's save it locally
        this.deferred_scenario_id.done((id) => {
          return (this.scenario_id = id);
        });
      }
      // @debug "Scenario URL: #{@scenario_url()}"

      // return the deferred object, so we can attach callbacks as needed
      return this.deferred_scenario_id;
    }

    // Creates a new scenario if no @scenario_id is set, or resumes an existing
    // scenario if it is.
    //
    // The callback will yield the data returned by ETEngine.
    create_or_resume_scenario() {
      if (this.deferred_scenario) {
        return this.deferred_scenario;
      } else {
        this.deferred_scenario = this.scenario_id ? this.resume_scenario() : this.create_scenario();

        return this.deferred_scenario.done((data) => this.__apply_settings__(data));
      }
    }

    // Creates a new scenario on ETEngine using the ApiGateway settings.
    //
    // The callback will yield the data returned by ETEngine.
    create_scenario() {
      return jQuery.ajax({
        url: this.path("scenarios"),
        type: "POST",
        error: this.opts.defaultErrorHandler,
        headers: this.request_headers(),
        data: {
          include_inputs: true,
          scenario: this.scenario,
        },
      });
    }

    // Resumes an existing scenario on ETEngine.
    //
    // The callback will yield the data returned by ETEngine.
    resume_scenario() {
      return jQuery.ajax({
        url: this.path(`scenarios/${this.scenario_id}`),
        type: "GET",
        error: this.opts.defaultErrorHandler,
        headers: this.request_headers(),
        data: {
          include_inputs: true,
        },
      });
    }

    // It clones the current scenario with the given attributes.
    //
    // @example
    //     api.scenario_id          # => 20121
    //     api.changeScenario
    //       attributes: {end_year: 2050}
    //       success: -> alert('changed')
    //     # The settings hash will change too.
    //     api.settings.end_year    # => 2050
    //     api.scenario_id          # => 20122
    //
    changeScenario({ attributes, success, error }) {
      this.__apply_settings__(attributes); // scenario_id will also change.

      const success_callback = (data, textStatus, jqXHR) => {
        const args = $.extend(DEFAULT_CALLBACK_ARGS, { scenario: data });
        this.__apply_settings__(args.scenario); // scenario_id changed.
        return success(args, data, textStatus, jqXHR); // The supplied callback.
      };

      const params = { scenario: this.scenario };
      return this.ensure_id().done((id) => {
        const url = this.path("scenarios");

        return this.__call_api__(url, params, success_callback, error, { type: "POST" });
      });
    }

    // resets all slider settings also the ones from a preset scenario.
    // keeps area_code, end_year, use_fce and peak_load settings
    //
    resetScenario({ success, error }) {
      const success_callback = function (data, textStatus, jqXHR) {
        const args = $.extend(DEFAULT_CALLBACK_ARGS, data);
        return success(args, data, textStatus, jqXHR);
      };

      return this.ensure_id().done((id) => {
        const url = this.path(`scenarios/${this.scenario_id}`);
        return this.__call_api__(url, { reset: 1 }, success_callback, error, { type: "PUT" });
      });
    }

    // Loads scenarios/../inputs.json that contains attributes for the inputs.
    //
    user_values({ success, error, extras, cache }) {
      var headers = this.request_headers()
      var data = { include_extras: extras }
      if (!cache) {
        data = { include_extras: extras, time: new Date.getTime() }
        headers = $.extend(headers, { "cache-control": "no-cache, no-store, max-age=0, must-revalidate" })
      }
      return this.ensure_id().done(() => {
        return $.ajax({
          url: this.path(`scenarios/${this.scenario_id}/inputs.json`),
          data: data,
          headers: headers,
          success,
          error,
          cache: cache,
          dataType: "json",
        });
      });
    }

    // Currently ajax calls are queued with a simple $.ajaxQueue.
    // TODO: when there's multiple requests in the queue they should be reduced
    //   to one call, by merging inputs and queries. But only if the callbacks
    //   are the same too.
    //
    // inputs    - a hash of input keys and values (defined by user)
    // queries   - an array of gquery keys that gets returned by the api.
    // success   - callback for successful api call
    // error     - callback for errornous api call
    // reset     - set to true to reset values on the engine side
    //
    // @example success callback:
    //     api.update {success: (data) -> data.results.dashboard_total_costs.future }
    //     api.update {success: ({results, settings, inputs}) -> ... }
    //     # The original parameters are appended:
    //     api.update {success: (data, response, textStatus, jqXHR) -> ... }
    //
    //     handle_api_result: ({results, settings, inputs}, response, textStatus, jqXHR) =>
    //
    // update is the default api request that sets new inputs, updates settings
    // and returns results of queries)
    //
    update({ inputs, queries, success, error, reset, settings }) {
      return this.ensure_id().done((id) => {
        if (!error) {
          error = this.opts.defaultErrorHandler;
        }

        const params = {
          autobalance: true,
          scenario: {
            user_values: inputs,
          },
        };

        // omit empty key => null pairs
        if (queries != null) {
          params.gqueries = queries;
        }
        if (reset != null) {
          params.reset = reset;
        }

        if (settings != null) {
          const object = this.__pick_scenario_settings__(settings);
          for (let key in object) {
            const value = object[key];
            params.scenario[key] = value;
          }
        }

        const url = this.path(`scenarios/${this.scenario_id}`);

        // we modifiy the success_callback here and not in __call_api__
        // because I want __call_api__ to be generic. the parsing of results
        // only is needed in this specific request type.
        const success_callback = (data, textStatus, jqXHR) => {
          const args = this.__parse_success__(data, textStatus, jqXHR);
          return success(args, data, textStatus, jqXHR);
        };

        return this.__call_api__(url, params, success_callback, error);
      });
    }

    // maps the results from a update call and to the default argument.
    //
    // {
    //   results: {query_key: {present: 12, future: 14, etc}}
    //   inputs:  {123: 0.4}
    //   scenario: {...}
    // }
    __parse_success__(data, textStatus, jqXHR) {
      const mapping = {
        results: data.gqueries,
        inputs: data.scenario.user_values || {},
        scenario: data.scenario,
      };

      return $.extend(DEFAULT_CALLBACK_ARGS, mapping);
    }

    // __call_api should be a general
    //
    // params    - the params sent to the server
    // success   - callback for successful api call
    // error     - callback for errornous api call
    __call_api__(url, params, success, error, ajaxOptions) {
      if (ajaxOptions == null) {
        ajaxOptions = {};
      }
      const opts = $.extend(
        {
          url,
          data: params,
          type: "PUT",
          dataType: "json",
          headers: this.request_headers(),
        },
        ajaxOptions
      );

      this.opts.beforeLoading();
      ApiGateway.queue.push("call_api");

      const { afterLoading } = this.opts;
      return jQuery
        .ajaxQueue(opts)
        .done((data, textStatus, jqXHR) => success(data, textStatus, jqXHR))
        .fail(
          (
            jqXHR,
            textStatus,
            err // TODO: error should return an array of error messages
          ) => error(jqXHR, textStatus, err)
        )
        .always(function () {
          ApiGateway.queue.pop();
          if (ApiGateway.queue.length === 0) {
            return afterLoading();
          }
        });
    }

    // extracts only keys relevant for settings from hsh
    __pick_scenario_settings__(hsh) {
      const result = {};
      for (let key of ["area_code", "end_year", "preset_id", "use_fce", "source", "scale"]) {
        if (hsh[key] != null) {
          result[key] = hsh[key];
        }
      }

      if (hsh.preset_scenario_id) {
        result.scenario_id = hsh.preset_scenario_id;
      }

      return result;
    }

    // Sets the path used when sending API requests to ETEngine. Self-destructs
    // after the first time it is called.
    // This hard-coded stuff from ETFlex should better be removed
    //
    setPath(path, proxy_path, offline) {
      if (offline == null) {
        offline = false;
      }
      const ios4 = navigator.userAgent?.match(/CPU (iPhone )?OS 4_/);
      //  cors | ios4 | offl
      //   1       0      0   # => ok
      //   1       1      0   # => /ete
      //   1       0      1   # => /ete
      //   0      0/1    0/1  # => /ete
      //
      PATH =
        jQuery.support.cors && !ios4 && !offline
          ? // remove trailing slash "et-engine.com/"
            (path = path.replace(/\/$/, ""))
          : proxy_path;

      this.isBeta = path.match(/^https?:\/\/beta\./) != null;
      return (this.setPath = function () {});
    }

    // Creates a path for an API request. Prevents malicious users messing with the
    // API variable.
    //
    // path - The URL path; appended to the API path.
    //
    path(suffix) {
      return `${PATH}/api/v3/${suffix}`;
    }
  });
  Cls.initClass();
  return Cls;
})();

if (typeof exports !== "undefined") {
  exports.Etmodel = Etmodel;
  exports.ApiGateway = ApiGateway;
}
