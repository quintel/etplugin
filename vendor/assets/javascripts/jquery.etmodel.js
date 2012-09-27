// Generated by CoffeeScript 1.3.3
(function() {
  var root,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty;

  root = typeof global !== "undefined" && global !== null ? global : window;

  if ((typeof $ !== "undefined" && $ !== null)) {
    $.fn.extend({
      etmodel: function(options) {
        var scenarios, self;
        if (options == null) {
          options = {};
        }
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
      if (options == null) {
        options = {};
      }
      this.handle_result = __bind(this.handle_result, this);

      this.base = $(base);
      this.scenario = {
        end_year: $('input[data-etm-end-year]', this.base).attr('data-etm-end-year') || 2050,
        area_code: $('input[data-etm-area-code]', this.base).attr('data-etm-area-code') || 'nl'
      };
      this.api = new ApiGateway($.extend(this.scenario, options));
      this.inputs = $('[data-etm-input]', this.base).bind('change', function() {
        return _this.update();
      });
      this.outputs = $('[data-etm-output]', this.base);
      this.outputs.each(function(i, el) {
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
      var key, result, results, _results;
      results = _arg.results;
      _results = [];
      for (key in results) {
        if (!__hasProp.call(results, key)) continue;
        result = results[key];
        _results.push($("[data-etm-output=" + key + "]", this.base).each(function(i, el) {
          var callback;
          callback = $(el).attr('data-etm-update') || 'format';
          return Etmodel.Callbacks[callback](el, result);
        }));
      }
      return _results;
    };

    return Etmodel;

  })();

  Etmodel.Callbacks = (function() {

    function Callbacks() {}

    Callbacks.format = function(element, result) {
      var format_str;
      format_str = $(element).attr('data-etm-format') || 'future;round';
      result = new Etmodel.ResultFormatter(result, format_str).value();
      return $(element).html(result);
    };

    return Callbacks;

  })();

  Etmodel.ResultFormatter = (function() {

    function ResultFormatter(result, format_string) {
      this.result = result;
      this.format_string = format_string != null ? format_string : "future;round";
    }

    ResultFormatter.prototype.value = function() {
      var args, formatter, method, params, result, _i, _len, _ref, _ref1;
      result = this.result;
      _ref = this.format_string.split(";");
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        formatter = _ref[_i];
        _ref1 = formatter.split(":"), method = _ref1[0], args = _ref1[1];
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
      if (f === 0 && p === 0) {
        return 0.0;
      }
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
    var DEFAULT_CALLBACK_ARGS, PATH, VERSION;

    PATH = null;

    VERSION = '0.2.4';

    DEFAULT_CALLBACK_ARGS = {
      results: {},
      inputs: {},
      scenario: {}
    };

    ApiGateway.queue = [];

    ApiGateway.prototype.default_options = {
      api_path: 'http://www.et-engine.com',
      api_proxy_path: '/ete',
      offline: false,
      beforeLoading: function() {},
      afterLoading: function() {},
      defaultErrorHandler: function() {
        if (typeof console !== "undefined" && console !== null) {
          return console.log("ApiGateway.update Error:", arguments);
        }
      }
    };

    function ApiGateway(opts) {
      this.user_values = __bind(this.user_values, this);
      this.__apply_settings__(opts);
      this.setPath(this.opts.api_path, this.opts.api_proxy_path, this.opts.offline);
    }

    ApiGateway.prototype.__apply_settings__ = function(opts) {
      this.opts = $.extend({}, this.default_options, opts);
      this.scenario = this.__pick_scenario_settings__(this.opts);
      return this.scenario_id = this.opts.scenario_id || this.opts.id || null;
    };

    ApiGateway.prototype.ensure_id = function() {
      var id,
        _this = this;
      if (this.deferred_scenario_id) {
        return this.deferred_scenario_id;
      }
      if (id = this.scenario_id) {
        this.deferred_scenario_id = $.Deferred().resolve(id);
      } else {
        this.deferred_scenario_id = $.ajax({
          url: this.path("scenarios"),
          type: 'POST',
          data: {
            scenario: this.scenario
          },
          timeout: 10000,
          error: this.opts.defaultErrorHandler
        }).pipe(function(data) {
          return data.id;
        });
        this.deferred_scenario_id.done(function(id) {
          return _this.scenario_id = id;
        });
      }
      return this.deferred_scenario_id;
    };

    ApiGateway.prototype.changeScenario = function(_arg) {
      var attributes, error, params, success, success_callback,
        _this = this;
      attributes = _arg.attributes, success = _arg.success, error = _arg.error;
      this.__apply_settings__(attributes);
      success_callback = function(data, textStatus, jqXHR) {
        var args;
        args = $.extend(DEFAULT_CALLBACK_ARGS, {
          scenario: data
        });
        _this.__apply_settings__(args.scenario);
        return success(args, data, textStatus, jqXHR);
      };
      params = {
        scenario: this.scenario
      };
      return this.ensure_id().done(function(id) {
        var url;
        url = _this.path("scenarios");
        return _this.__call_api__(url, params, success_callback, error, {
          type: 'POST'
        });
      });
    };

    ApiGateway.prototype.resetScenario = function(_arg) {
      var error, success, success_callback,
        _this = this;
      success = _arg.success, error = _arg.error;
      success_callback = function(data, textStatus, jqXHR) {
        var args;
        args = $.extend(DEFAULT_CALLBACK_ARGS, data);
        return success(args, data, textStatus, jqXHR);
      };
      return this.ensure_id().done(function(id) {
        var url;
        url = _this.path("scenarios/" + _this.scenario_id);
        return _this.__call_api__(url, {
          reset: 1
        }, success_callback, error, {
          type: 'PUT'
        });
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
          error: error,
          dataType: 'json',
          timeout: 15000
        });
      });
    };

    ApiGateway.prototype.userValues = ApiGateway.prototype.user_values;

    ApiGateway.prototype.update = function(_arg) {
      var error, inputs, queries, settings, success,
        _this = this;
      inputs = _arg.inputs, queries = _arg.queries, success = _arg.success, error = _arg.error, settings = _arg.settings;
      return this.ensure_id().done(function() {
        var key, params, success_callback, url, value, _ref;
        error || (error = _this.opts.defaultErrorHandler);
        params = {
          autobalance: true,
          scenario: {
            user_values: inputs
          }
        };
        if (queries != null) {
          params.gqueries = queries;
        }
        if (settings != null) {
          _ref = _this.__pick_scenario_settings__(settings);
          for (key in _ref) {
            value = _ref[key];
            params.scenario[key] = value;
          }
        }
        url = _this.path("scenarios/" + _this.scenario_id);
        success_callback = function(data, textStatus, jqXHR) {
          var args;
          args = _this.__parse_success__(data, textStatus, jqXHR);
          return success(args, data, textStatus, jqXHR);
        };
        return _this.__call_api__(url, params, success_callback, error);
      });
    };

    ApiGateway.prototype.__parse_success__ = function(data, textStatus, jqXHR) {
      var mapping, _ref;
      mapping = {
        results: data.gqueries,
        inputs: (_ref = data.settings) != null ? _ref.user_values : void 0,
        scenario: data.settings
      };
      return $.extend(DEFAULT_CALLBACK_ARGS, mapping);
    };

    ApiGateway.prototype.__call_api__ = function(url, params, success, error, ajaxOptions) {
      var afterLoading, opts;
      if (ajaxOptions == null) {
        ajaxOptions = {};
      }
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
        return success(data, textStatus, jqXHR);
      }).fail(function(jqXHR, textStatus, err) {
        return error(jqXHR, textStatus, err);
      }).always(function() {
        ApiGateway.queue.pop();
        if (ApiGateway.queue.length === 0) {
          return afterLoading();
        }
      });
    };

    ApiGateway.prototype.__pick_scenario_settings__ = function(hsh) {
      var key, result, _i, _len, _ref;
      result = {};
      _ref = ['area_code', 'end_year', 'preset_id', 'use_fce', 'source'];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        key = _ref[_i];
        if (hsh[key] !== void 0) {
          result[key] = hsh[key];
        }
      }
      if (hsh.preset_scenario_id) {
        result.scenario_id = hsh.preset_scenario_id;
      }
      return result;
    };

    ApiGateway.prototype.setPath = function(path, proxy_path, offline) {
      var ios4, _ref;
      if (offline == null) {
        offline = false;
      }
      ios4 = (_ref = navigator.userAgent) != null ? _ref.match(/CPU (iPhone )?OS 4_/) : void 0;
      PATH = jQuery.support.cors && !ios4 && !offline ? path = path.replace(/\/$/, '') : proxy_path;
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
