root = global ? window

class root.Chart
  # The constructor accepts a DOM element with the proper data attributes or an
  # object with all the various settings
  #
  constructor: (options = {}) ->
    if options instanceof Element
      @container = $ options # wrap it in jQuery
      @_gqueries = @container.data('etm-series').split(',')
      @type = @container.data('etm-chart')
    else
      @_gqueries = options.series
      @type = options.type

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

