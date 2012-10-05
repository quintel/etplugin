root = global ? window

class root.Chart
  # The constructor accepts a DOM element with the proper data attributes or an
  # object with all the various settings
  #
  # If you're passing an object then the hash options are:
  #   container - CSS selector of the element that will hold the chart
  #   series    - array of the gqueries that should be plotted
  #   type      - chart type (stacked_bar or bezier at the moment)
  #
  # If you're passing a DOM element then the options are extracted from the
  # element attributes:
  #   etm-chart-type   - chart type
  #   etm-chart-series - list of gqueries separated by a comma
  #
  constructor: (options = {}) ->
    if options instanceof Element
      @container = $ options # wrap it in jQuery
      @_gqueries = @container.data('etm-chart-series').split(',')
      @type = @container.data('etm-chart-type')
    else
      @_gqueries = options.series
      @type = options.type
      @container = options.container

    @_gqueries = @_gqueries || []

    view_class = switch @type
      when 'stacked_bar' then StackedBarChart
      when 'bezier'      then BezierChart

    throw "Unsupported chart type" unless view_class

    @view = new view_class(@container[0], @_gqueries)

  # Returns an array of the gqueries required by the chart
  #
  gqueries: => @_gqueries

  refresh: (results) => @view.refresh(results)

# Base class that holds shared functionality
# The derived classes should define two methods: the constructor, that takes
# care of the initial rendering, and `refresh`, that updates the data
#
class root.BaseChart
  constructor: (container, gqueries) ->
    @container = container
    @gqueries = gqueries
    @colors = d3.scale.category20()

  # Simple jQuery-based array flattener. Underscore provides a similar method
  flatten: (arr) -> $.map arr, (x) -> x

  # We calculate this to set the upper limit of the y scale
  #
  tallest_column_value: (data) =>
    present = future = 0
    for g in @gqueries
      present += data.results[g].present
      future  += data.results[g].future
    Math.max present, future

  # Draws a legend box
  #
  # svg  - the SVG element that will hold the legend (default: @svg)
  # opts - an option array
  #      series - a string array of legend items (default: @gqueries)
  #      offset - the vertical offset
  #
  draw_legend: (svg, opts = {}) =>
    svg ?= @svg
    series = opts.series || @gqueries
    offset = opts.offset || 0
    legend = svg.append('svg:g')
      .attr("transform", "translate(10,#{offset})")
      .selectAll("svg.legend")
      .data(series)
      .enter()
      .append("svg:g")
      .attr("class", "legend")
      .attr("transform", (d, i) ->
        "translate(0, #{i * 20})")
      .attr("height", 30)
      .attr("width", 90)
    legend.append("svg:rect")
      .attr("width", 10)
      .attr("height", 10)
      .attr("fill", (d) => @colors d)
    legend.append("svg:text")
      .attr("x", 15)
      .attr("y", 10)
      .text((d) -> d)

