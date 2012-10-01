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

  # Returns an array of the gqueries required by the chart
  #
  gqueries: => @_gqueries

  # Initial rendering
  #
  render: =>
    console.log 'rendering'
    @container = d3.select(@dom[0])
      .append 'div'

    @container.selectAll('div.item')
      .data(@_gqueries)
      .enter()
      .append('div')
      .text((d) -> d)

    @rendered = true

  # Updates values
  #
  refresh: (data = {}) =>
    @render() unless @rendered
    console.log 'refreshing'