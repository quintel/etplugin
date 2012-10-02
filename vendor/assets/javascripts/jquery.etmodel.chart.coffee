root = global ? window

class root.Chart
  # The constructor accepts a DOM element with the proper data attributes or an
  # object with all the various settings
  #
  constructor: (options = {}) ->
    if options instanceof Element
      @dom = $ options # wrap it in jQuery
      @_gqueries = @dom.data('etm-series').split(',')
      @type = @dom.data('etm-chart')
    else
      @_gqueries = options.series
      @type = options.type

    @_gqueries = @_gqueries || []

    view_class = switch @type
      when 'stacked_bar' then StackedBarChart

    throw "Unsupported chart type" unless view_class

    @view = new view_class(@dom[0], @_gqueries)

  # Returns an array of the gqueries required by the chart
  #
  gqueries: => @_gqueries

  refresh: (results) => @view.refresh(results)

# Base class that holds shared functionality
# The derived classes should define two methods: the constructor, that takes
# care of the initial rendering, and `refresh`, that updates the data
#
class root.BaseChart
  constructor: (dom, gqueries) ->
    @gqueries = gqueries

class root.StackedBarChart extends root.BaseChart
  constructor: (dom, gqueries) ->
    super(dom, gqueries)
    @container = d3.select(dom)
      .append 'div'

  render: (data) ->
    # console.log 'rendering'
    console.log "End year: #{data.scenario.end_year}"
    @container.selectAll('div.item')
      .data(@gqueries, (d) -> d)
      .enter()
      .append('div')
      .attr('class', 'item')
      .text((d) -> d)
    @rendered = true

  # Updates values
  #
  refresh: (data = {}) =>
    # console.log data
    @render(data) unless @rendered
    console.log 'refreshing'
    @container.selectAll('div.item')
      .data(@gqueries, (d) -> d)
      .text((d) -> "#{d}: #{data.results[d].future}")
