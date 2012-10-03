// Generated by CoffeeScript 1.3.3
(function() {
  var root,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  root = typeof global !== "undefined" && global !== null ? global : window;

  root.BezierChart = (function(_super) {

    __extends(BezierChart, _super);

    function BezierChart(container, gqueries) {
      this.prepare_data = __bind(this.prepare_data, this);

      this.refresh = __bind(this.refresh, this);

      this.render = __bind(this.render, this);
      BezierChart.__super__.constructor.call(this, container, gqueries);
    }

    BezierChart.prototype.render = function(data) {
      var margins, nested, stacked_data,
        _this = this;
      margins = {
        top: 20,
        bottom: 20,
        left: 30,
        right: 40
      };
      this.width = 494 - (margins.left + margins.right);
      this.height = 494 - (margins.top + margins.bottom);
      this.series_height = 300;
      this.start_year = 2010;
      this.end_year = data.scenario.end_year;
      this.x = d3.scale.linear().range([0, this.width - 15]).domain([this.start_year, this.end_year]);
      this.y = d3.scale.linear().range([0, this.series_height]).domain([0, this.tallest_column_value(data)]);
      this.inverted_y = this.y.copy().range([this.series_height, 0]);
      this.y_axis = d3.svg.axis().scale(this.inverted_y).ticks(4).tickSize(-440, 10, 0).orient("right");
      this.colors = d3.scale.category20();
      this.stack_method = d3.layout.stack().offset('zero').values(function(d) {
        return d.values;
      });
      this.nest = d3.nest().key(function(d) {
        return d.id;
      });
      nested = this.nest.entries(this.prepare_data(data));
      stacked_data = this.stack_method(nested);
      this.area = d3.svg.area().interpolate('basis').x(function(d) {
        return _this.x(d.x);
      }).y0(function(d) {
        return _this.inverted_y(d.y0);
      }).y1(function(d) {
        return _this.inverted_y(d.y0 + d.y);
      });
      this.svg = d3.select(this.container).append('svg:svg').attr("height", this.height + margins.top + margins.bottom).attr("width", this.width + margins.left + margins.right).attr("class", 'etm-chart stacked_bar').append("svg:g").attr("transform", "translate(" + margins.left + ", " + margins.top + ")");
      this.svg.selectAll('text.year').data([this.start_year, this.end_year]).enter().append('svg:text').attr('class', 'year').text(function(d) {
        return d;
      }).attr('x', function(d, i) {
        if (i === 0) {
          return -10;
        } else {
          return 330;
        }
      }).attr('y', this.series_height + 15).attr('dx', 45);
      this.svg.append("svg:g").attr("class", "y_axis").attr("transform", "translate(" + (this.width - 15) + ", 0)").call(this.y_axis);
      this.svg.selectAll('path.serie').data(stacked_data, function(s) {
        return s.key;
      }).enter().append('svg:path').attr('class', 'serie').attr('d', function(d) {
        return _this.area(d.values);
      }).style('fill', function(d) {
        return _this.colors(d.key);
      });
      return this.rendered = true;
    };

    BezierChart.prototype.refresh = function(data) {
      var stacked_data, tallest,
        _this = this;
      if (data == null) {
        data = {};
      }
      if (!this.rendered) {
        this.render(data);
      }
      tallest = this.tallest_column_value(data);
      this.y = this.y.domain([0, tallest]);
      this.inverted_y = this.inverted_y.domain([0, tallest]);
      this.svg.selectAll(".y_axis").transition().call(this.y_axis.scale(this.inverted_y));
      this.svg.selectAll('g.rule').data(this.y.ticks()).transition().attr('transform', function(d) {
        return "translate(0, " + (_this.inverted_y(d)) + ")";
      });
      stacked_data = this.stack_method(this.nest.entries(this.prepare_data(data)));
      return this.svg.selectAll('path.serie').data(stacked_data, function(s) {
        return s.key;
      }).transition().attr('d', function(d) {
        return _this.area(d.values);
      });
    };

    BezierChart.prototype.prepare_data = function(data) {
      var future, g, left_stack, max_value, mid_point, mid_stack, mid_year, min_value, output, present, right_stack, _i, _len, _ref;
      output = [];
      left_stack = 0;
      mid_stack = 0;
      right_stack = 0;
      _ref = this.gqueries;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        g = _ref[_i];
        present = data.results[g].present || 0;
        future = data.results[g].future || 0;
        min_value = Math.min(left_stack + present, right_stack + future);
        max_value = Math.max(left_stack + present, right_stack + future);
        mid_point = future > present ? present : future;
        mid_point += mid_stack;
        mid_point = mid_point < min_value ? min_value : mid_point > max_value ? max_value : mid_point;
        mid_point -= mid_stack;
        mid_stack += mid_point;
        left_stack += present;
        right_stack += future;
        mid_year = (this.start_year + this.end_year) / 2;
        output.push([
          {
            x: this.start_year,
            y: present,
            id: g
          }, {
            x: mid_year,
            y: mid_point,
            id: g
          }, {
            x: this.end_year,
            y: future,
            id: g
          }
        ]);
      }
      return this.flatten(output);
    };

    return BezierChart;

  })(root.BaseChart);

}).call(this);
