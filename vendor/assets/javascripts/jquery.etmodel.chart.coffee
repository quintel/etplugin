root = global ? window

class root.Chart
  # The constructor accepts a DOM element with the proper data attributes or an
  # object with all the various settings
  #
  constructor: (options = {}) ->
    console.log "New chart!"
    if options instanceof Element
      @dom = $ options # wrap it in jQuery
      @_gqueries = @dom.data('etm-series').split(',')
    else
      @_gqueries = options.series
    @_gqueries = @_gqueries || []
    console.log @_gqueries
    @view = new StackedBarChart @dom[0], @_gqueries

  # Returns an array of the gqueries required by the chart
  #
  gqueries: => @_gqueries

  refresh: (results) => @view.refresh(results)

# Base class that holds shared functionality
# The derived classes should define two methods: the constructor, that takes
# care of the initial rendering, and `refresh`, that updates the data
#
class root.BaseChart

class root.StackedBarChart extends root.BaseChart
  constructor: (dom, gqueries) ->
    @gqueries = gqueries
    console.log 'rendering'
    @container = d3.select(dom)
      .append 'div'

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
    @render() unless @rendered
    console.log 'refreshing'
    @container.selectAll('div.item')
      .data(@gqueries, (d) -> d)
      .text((d) -> "#{d}: #{data[d].future}")
