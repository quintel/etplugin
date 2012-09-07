(function() {
  var root,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = Object.prototype.hasOwnProperty;

  root = typeof global !== "undefined" && global !== null ? global : window;

  if ((typeof $ !== "undefined" && $ !== null)) {
    $.fn.extend({
      etmodel: function(options) {
        var scenarios, self;
        if (options == null) options = {};
        self = $.fn.etmodel;
        scenarios = [];
        $(this).each(function(i, el) {
          var etm;
          etm = new Etmodel(el, options);
          scenarios.push(etm);
          return etm.update();
        });
        return scenarios;
      }
    });
  } else {
    if (typeof console !== "undefined" && console !== null) {
      if (typeof console.warn === "function") {
        console.warn("jQuery not yet included");
      }
    }
  }

  root.Etmodel = (function() {

    function Etmodel(base, options) {
      var _this = this;
      if (options == null) options = {};
      this.handle_result = __bind(this.handle_result, this);
      this.base = $(base);
      this.settings = {
        end_year: $('input[data-etm-end-year]', this.base).attr('data-etm-end-year') || 2050,
        area_code: $('input[data-etm-area-code]', this.base).attr('data-etm-area-code') || 'nl'
      };
      this.api = new ApiGateway($.extend(this.settings, options));
      this.inputs = $('[data-etm-input]', this.base).bind('change', function() {
        return _this.update();
      });
      this.outputs = $('[data-etm-output]', this.base).each(function(i, el) {
        return $(el).html('...');
      });
    }

    Etmodel.prototype.update = function() {
      var inputs, query_keys;
      inputs = {};
      this.inputs.each(function(i, el) {
        return inputs[$(el).attr('data-etm-input')] = $(el).val();
      });
      query_keys = [];
      this.outputs.each(function(i, el) {
        return query_keys.push($(el).attr('data-etm-output'));
      });
      return this.api.update({
        inputs: inputs,
        queries: $.unique(query_keys),
        success: this.handle_result
      });
    };

    Etmodel.prototype.handle_result = function(_arg) {
      var key, results, values, _results;
      results = _arg.results;
      _results = [];
      for (key in results) {
        if (!__hasProp.call(results, key)) continue;
        values = results[key];
        _results.push($("[data-etm-output=" + key + "]", this.base).each(function(i, el) {
          var format_str, result;
          format_str = $(el).attr('data-etm-format') || 'future;round';
          result = new Etmodel.ResultFormatter(values, format_str).value();
          return $(el).html(result);
        }));
      }
      return _results;
    };

    return Etmodel;

  })();

  Etmodel.ResultFormatter = (function() {

    function ResultFormatter(result, format_string) {
      this.result = result;
      this.format_string = format_string != null ? format_string : "future;round";
    }

    ResultFormatter.prototype.value = function() {
      var args, formatter, method, params, result, _i, _len, _ref, _ref2;
      result = this.result;
      _ref = this.format_string.split(";");
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        formatter = _ref[_i];
        _ref2 = formatter.split(":"), method = _ref2[0], args = _ref2[1];
        params = [result].concat(args);
        result = this[method].apply(null, params);
      }
      return result;
    };

    ResultFormatter.prototype.valueOf = function() {
      return value();
    };

    ResultFormatter.prototype.toString = function() {
      return "" + (value());
    };

    ResultFormatter.prototype.future = function(result) {
      return result.future;
    };

    ResultFormatter.prototype.present = function(result) {
      return result.present;
    };

    ResultFormatter.prototype.delta = function(result) {
      var f, p;
      f = result.future;
      p = result.present;
      if (f === 0 && p === 0) return 0.0;
      return f / p - 1.0;
    };

    ResultFormatter.prototype.percent = function(number) {
      return number * 100;
    };

    ResultFormatter.prototype.round = function(number, precision) {
      var multiplier;
      precision || (precision = 1);
      precision = parseInt(precision);
      multiplier = Math.pow(10, precision);
      if (precision > 0) {
        return Math.round(number * multiplier) / multiplier;
      } else if (precision === 0) {
        return Math.round(number);
      } else {
        return Math.round(number * multiplier) / multiplier;
      }
    };

    return ResultFormatter;

  })();

  root.ApiGateway = (function() {
    var PATH, VERSION;

    PATH = null;

    VERSION = '0.1';

    ApiGateway.queue = [];

    ApiGateway.prototype.scenario_id = null;

    ApiGateway.prototype.isBeta = false;

    ApiGateway.prototype.default_options = {
      api_path: 'http://www.et-engine.com',
      offline: false,
      beforeLoading: function() {},
      afterLoading: function() {},
      defaultErrorHandler: function() {
        console.log("ApiGateway.update Error:");
        return console.log(arguments);
      }
    };

    function ApiGateway(opts) {
      this.user_values = __bind(this.user_values, this);      this.opts = $.extend({}, this.default_options, opts);
      this.settings = this.pickSettings(this.opts);
      this.scenario_id = this.opts.scenario_id || null;
      this.setPath(this.opts.api_path, this.opts.offline);
    }

    ApiGateway.prototype.ensure_id = function() {
      var id,
        _this = this;
      if (this.deferred_scenario_id) return this.deferred_scenario_id;
      if (id = this.scenario_id) {
        this.deferred_scenario_id = $.Deferred().resolve(id);
      } else {
        this.deferred_scenario_id = $.ajax({
          url: this.path("scenarios"),
          type: 'POST',
          data: {
            scenario: this.settings
          },
          timeout: 10000,
          error: this.opts.defaultErrorHandler
        }).pipe(function(d) {
          return d.id;
        });
        this.deferred_scenario_id.done(function(id) {
          return _this.scenario_id = id;
        });
      }
      return this.deferred_scenario_id;
    };

    ApiGateway.prototype.changeScenario = function(_arg) {
      var attributes, error, success;
      attributes = _arg.attributes, success = _arg.success, error = _arg.error;
      return this.settings = $.extend(this.settings, this.pickSettings(attributes));
    };

    ApiGateway.prototype.resetScenario = function() {};

    ApiGateway.prototype.update = function(_arg) {
      var error, inputs, queries, settings, success,
        _this = this;
      inputs = _arg.inputs, queries = _arg.queries, success = _arg.success, error = _arg.error, settings = _arg.settings;
      return this.ensure_id().done(function() {
        var params, success_callback, url;
        error || (error = _this.opts.defaultErrorHandler);
        params = {
          autobalance: true,
          scenario: {
            user_values: inputs
          }
        };
        if (queries != null) params.gqueries = queries;
        if (settings != null) params.settings = settings;
        url = _this.path("scenarios/" + _this.scenario_id);
        success_callback = function(data, textStatus, jqXHR) {
          var parsed_results;
          parsed_results = _this.__parse_success__(data, textStatus, jqXHR);
          return success(parsed_results, data, textStatus, jqXHR);
        };
        return _this.__call_api__(url, params, success_callback, error);
      });
    };

    ApiGateway.prototype.user_values = function(_arg) {
      var error, success,
        _this = this;
      success = _arg.success, error = _arg.error;
      return this.ensure_id().done(function() {
        return $.ajax({
          url: _this.path("scenarios/" + _this.scenario_id + "/inputs.json"),
          success: success,
          dataType: 'json',
          timeout: 15000
        });
      });
    };

    ApiGateway.prototype.__parse_success__ = function(data, textStatus, jqXHR) {
      var key, result, values, _ref, _ref2;
      result = {
        results: {},
        inputs: (_ref = data.settings) != null ? _ref.user_values : void 0,
        settings: data.settings || {}
      };
      _ref2 = data.gqueries;
      for (key in _ref2) {
        if (!__hasProp.call(_ref2, key)) continue;
        values = _ref2[key];
        result.results[key] = values;
      }
      return result;
    };

    ApiGateway.prototype.__call_api__ = function(url, params, success, error, ajaxOptions) {
      var afterLoading, opts;
      if (ajaxOptions == null) ajaxOptions = {};
      opts = $.extend({
        url: url,
        data: params,
        type: 'PUT',
        dataType: 'json',
        timeout: 10000,
        headers: {
          'X-Api-Agent': "jQuery.etmodel " + VERSION
        }
      }, ajaxOptions);
      this.opts.beforeLoading();
      ApiGateway.queue.push('call_api');
      afterLoading = this.opts.afterLoading;
      return jQuery.ajaxQueue(opts).done(function(data, textStatus, jqXHR) {
        ApiGateway.queue.pop();
        if (ApiGateway.queue.length === 0) afterLoading();
        return success(data, textStatus, jqXHR);
      }).fail(function(jqXHR, textStatus, err) {
        ApiGateway.queue.pop();
        if (ApiGateway.queue.length === 0) afterLoading();
        return error(jqXHR, textStatus, err);
      });
    };

    ApiGateway.prototype.pickSettings = function(hsh) {
      var key, result, _i, _len, _ref;
      result = {};
      _ref = ['area_code', 'end_year', 'preset_id', 'use_fce', 'source'];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        key = _ref[_i];
        result[key] = hsh[key];
      }
      if (hsh.preset_scenario_id) result.scenario_id = hsh.preset_scenario_id;
      return result;
    };

    ApiGateway.prototype.setPath = function(path, offline) {
      var ios4, _ref;
      if (offline == null) offline = false;
      ios4 = (_ref = navigator.userAgent) != null ? _ref.match(/CPU (iPhone )?OS 4_/) : void 0;
      PATH = jQuery.support.cors && !ios4 && !offline ? path.replace(/\/$/, '') : '/ete';
      this.isBeta = path.match(/^https?:\/\/beta\./) != null;
      return this.setPath = (function() {});
    };

    ApiGateway.prototype.path = function(suffix) {
      return "" + PATH + "/api/v3/" + suffix;
    };

    return ApiGateway;

  })();

  if (typeof exports !== 'undefined') {
    exports.Etmodel = Etmodel;
    exports.ApiGateway = ApiGateway;
  }

}).call(this);
