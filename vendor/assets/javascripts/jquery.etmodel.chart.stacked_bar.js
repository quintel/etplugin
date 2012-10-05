// Generated by CoffeeScript 1.3.3
(function() {
  var root,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  root = typeof global !== "undefined" && global !== null ? global : window;

  root.StackedBarChart = (function(_super) {

    __extends(StackedBarChart, _super);

    function StackedBarChart(container, gqueries) {
      this.prepare_data = __bind(this.prepare_data, this);

      this.refresh = __bind(this.refresh, this);

      this.render = __bind(this.render, this);
      StackedBarChart.__super__.constructor.call(this, container, gqueries);
    }

    StackedBarChart.prototype.render = function(data) {
      var margins, stacked_data, tallest_column,
        _this = this;
      margins = {
        top: 20,
        bottom: 20,
        left: 30,
        right: 40
      };
      this.width = 494 - (margins.left + margins.right);
      this.series_height = 300;
      this.height = this.series_height + 30 + this.gqueries.length * 20;
      this.start_year = 2010;
      this.end_year = data.scenario.end_year;
      this.x = d3.scale.ordinal().rangeRoundBands([0, this.width]).domain([this.start_year, this.end_year]);
      tallest_column = this.tallest_column_value(data);
      this.y = d3.scale.linear().range([0, this.series_height]).domain([0, tallest_column]);
      this.y_axis = d3.svg.axis().scale(this.y.copy().range([this.series_height, 0])).ticks(5).tickSize(-420, 10, 0).orient("right");
      this.stack_method = d3.layout.stack().offset('zero');
      stacked_data = this.flatten(this.stack_method(this.prepare_data(data)));
      this.svg = d3.select(this.container).append('svg:svg').attr("height", this.height + margins.top + margins.bottom).attr("width", this.width + margins.left + margins.right).attr("class", 'etm-chart stacked_bar').append("svg:g").attr("transform", "translate(" + margins.left + ", " + margins.top + ")");
      this.svg.selectAll('text.year').data([this.start_year, this.end_year]).enter().append('svg:text').attr('class', 'year').attr('text-anchor', 'middle').text(function(d) {
        return d;
      }).attr('x', function(d) {
        return _this.x(d);
      }).attr('y', this.series_height + 15).attr('dx', 65);
      this.svg.append("svg:g").attr("class", "y_axis").attr("transform", "translate(" + (this.width - 25) + ", 0)").call(this.y_axis);
      this.svg.selectAll('rect.serie').data(stacked_data, function(s) {
        return s.id;
      }).enter().append('svg:rect').attr('class', 'serie').attr("width", this.x.rangeBand() * 0.5).attr('x', function(s) {
        return _this.x(s.x) + 10;
      }).attr('y', function(d) {
        return _this.series_height - _this.y(d.y0 + d.y);
      }).attr('height', function(d) {
        return _this.y(d.y);
      }).style('fill', function(d) {
        return _this.colors(d.key);
      });
      this.draw_legend(this.svg, {
        series: this.gqueries,
        offset: this.series_height + 30
      });
      return this.rendered = true;
    };

    StackedBarChart.prototype.refresh = function(data) {
      var stacked_data, tallest_column,
        _this = this;
      if (data == null) {
        data = {};
      }
      if (!this.rendered) {
        this.render(data);
      }
      tallest_column = this.tallest_column_value(data);
      this.y.domain([0, tallest_column]);
      this.svg.selectAll(".y_axis").transition().call(this.y_axis.scale(this.y.copy().range([this.series_height, 0])));
      stacked_data = this.flatten(this.stack_method(this.prepare_data(data)));
      return this.svg.selectAll('rect.serie').data(stacked_data, function(s) {
        return s.id;
      }).transition().attr('y', function(d) {
        return _this.series_height - _this.y(d.y0 + d.y);
      }).attr('height', function(d) {
        return _this.y(d.y);
      });
    };

    StackedBarChart.prototype.prepare_data = function(data) {
      var g, output, _i, _len, _ref;
      output = [];
      _ref = this.gqueries;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        g = _ref[_i];
        output.push([
          {
            x: this.start_year,
            y: data.results[g].present,
            id: "" + g + "_present",
            key: g
          }, {
            x: this.end_year,
            y: data.results[g].future,
            id: "" + g + "_future",
            key: g
          }
        ]);
      }
      return output;
    };

    return StackedBarChart;

  })(root.BaseChart);

}).call(this);
