root = global ? window

class root.StackedBarChart extends root.BaseChart
  constructor: (container, gqueries) ->
    super(container, gqueries)

  render: (data) =>
    margins =
      top: 20
      bottom: 20
      left: 30
      right: 40
    @width  = 494 - (margins.left + margins.right)
    @height = 494 - (margins.top + margins.bottom)
    @series_height = 300 # max height of the bars

    @start_year = 2010
    @end_year   = data.scenario.end_year

    # The x scale is a discrete, two elements scale:
    #
    @x = d3.scale.ordinal()
      .rangeRoundBands([0, @width])
      .domain([@start_year, @end_year])

    # Prepares the y scale. The refresh method will take care of updating the
    # domain, that changes every time
    #
    tallest_column = @tallest_column_value(data)
    @y = d3.scale.linear().range([0, @series_height]).domain([0, tallest_column])

    # Prepares the y axis
    @y_axis = d3.svg.axis()
      .scale(@y.copy().range([@series_height, 0]))
      .ticks(5)
      .tickSize(-420, 10, 0)
      .orient("right")

    # the stack method will filter the data and calculate the offset for every
    # item. It returns a nested array, so we flatten it out before passing it to
    # the D3#data() method
    #
    @stack_method = d3.layout.stack().offset('zero')
    stacked_data = @flatten @stack_method(@prepare_data(data))

    # Creates the SVG container
    #
    @svg = d3.select(@container)
      .append('svg:svg')
      .attr("height", @height + margins.top + margins.bottom)
      .attr("width", @width + margins.left + margins.right)
      .append("svg:g")
      .attr("transform", "translate(#{margins.left}, #{margins.top})")

    # Draws the years at the bottom of the chart
    #
    @svg.selectAll('text.year')
      .data([@start_year, @end_year])
      .enter().append('svg:text')
      .attr('class', 'year')
      .text((d) -> d)
      .attr('x', (d) => @x(d) + 10)
      .attr('y', @series_height + 10)
      .attr('dx', 45)

    # Draws the y axis
    #
    @svg.append("svg:g")
      .attr("class", "y_axis")
      # move to the right and leave some space
      .attr("transform", "translate(#{@width - 25}, 0)")
      .call(@y_axis)

    # Color setup
    #
    @colors = d3.scale.category20()

    # And finally draw the blocks
    #
    @svg.selectAll('rect.serie')
      .data(stacked_data, (s) -> s.id)
      .enter().append('svg:rect')
      .attr('class', 'serie')
      .attr("width", @x.rangeBand() * 0.5)
      .attr('x', (s) => @x(s.x) + 10)
      .attr('y', (d) => @series_height - @y(d.y0 + d.y))
      .attr('height', (d) => @y(d.y))
      .style('fill', (d) => @colors d.key)

    @rendered = true

  # Updates values
  #
  refresh: (data = {}) =>
    @render(data) unless @rendered
    tallest_column = @tallest_column_value(data)
    @y.domain([0, tallest_column])

    # Update the axis
    #
    @svg.selectAll(".y_axis")
      .transition()
      .call(@y_axis.scale(@y.copy().range([@series_height, 0])))

    # Update the blocks
    #
    stacked_data = @flatten @stack_method(@prepare_data(data))
    @svg.selectAll('rect.serie')
      .data(stacked_data, (s) -> s.id)
      .transition()
      .attr('y', (d) => @series_height - @y(d.y0 + d.y))
      .attr('height', (d) => @y(d.y))

  # The stack layout method needs data in a precise format
  prepare_data: (data) =>
    output = []
    for g in @gqueries
      output.push [
        { x: @start_year, y: data.results[g].present, id: "#{g}_present", key: g},
        { x: @end_year,   y: data.results[g].future,  id: "#{g}_future",  key: g}
      ]
    output

  # We calculate this to set the upper limitt of the y scale
  #
  tallest_column_value: (data) =>
    present = future = 0
    for g in @gqueries
      present += data.results[g].present
      future  += data.results[g].future
    Math.max present, future
