root = global ? window

class root.BezierChart extends root.BaseChart
  constructor: (container, gqueries) ->
    super(container, gqueries)

  # This chart rendering is fairly complex. Here is the big picture:
  # The bezier chart is basically a stacked area chart; D3 provides some
  # utility methods that calculate the offset for stacked data. It expects
  # data to be given in a specific format and then it will add the
  # calculated attributes in place. Check the y0 attribute for instance.
  #
  # Once we have the stacked data, grouped by serie key, we can pass the array
  # of values to the SVG area method, that will create the SVG attributes
  # required to draw the paths (and add some nice interpolations)
  #
  render: (data) =>
    margins =
      top: 20
      bottom: 20
      left: 30
      right: 40
    @width  = 494 - (margins.left + margins.right)
    @series_height = 300 # max height of the bars
    @height = @series_height +
              30 +
              @gqueries.length * 20

    @start_year = 2010
    @end_year   = data.scenario.end_year

    @x = d3.scale.linear()
      .range([0, @width - 15]).domain([@start_year, @end_year])

    # Prepares the y scale. The refresh method will take care of updating the
    # domain, that changes every time
    #
    @y = d3.scale.linear()
      .range([0, @series_height])
      .domain([0, @tallest_column_value(data)])
    @inverted_y = @y.copy().range([@series_height, 0])

    # Prepares the y axis
    @y_axis = d3.svg.axis()
      .scale(@inverted_y)
      .ticks(4)
      .tickSize(-410, 10, 0)
      .tickFormat((x) => @humanize_value x)
      .orient("right")

    # the stack method will filter the data and calculate the offset for every
    # item. The values function tells this method that the values it will
    # operate on are an array held inside the values member. This member will
    # be filled automatically by the nesting method
    @stack_method = d3.layout.stack().offset('zero').values((d) -> d.values)
    # This method groups the series by key, creating an array of objects
    @nest = d3.nest().key((d) -> d.id)
    # Run the stack method on the nested entries
    nested = @nest.entries @prepare_data(data)
    stacked_data = @stack_method(nested)

    # This method will return the SVG area attributes. The values it receives
    # should be already stacked
    @area = d3.svg.area()
      .interpolate('basis')
      .x((d) => @x d.x)
      .y0((d) => @inverted_y d.y0)
      .y1((d) => @inverted_y(d.y0 + d.y))

    # Creates the SVG container
    #
    @svg = d3.select(@container)
      .append('svg:svg')
      .attr("height", @height + margins.top + margins.bottom)
      .attr("width", @width + margins.left + margins.right)
      .attr("class", 'etm-chart stacked_bar')
      .append("svg:g")
      .attr("transform", "translate(#{margins.left}, #{margins.top})")

    # Draws the years at the corners
    #
    @svg.selectAll('text.year')
      .data([@start_year, @end_year])
      .enter().append('svg:text')
      .attr('class', 'year')
      .text((d) -> d)
      .attr('text-anchor', 'middle')
      .attr('x', (d, i) => if i == 0 then 0 else @width - 15) # chart corners
      .attr('y', @series_height + 15)

    # Draws the y axis
    #
    @svg.append("svg:g")
      .attr("class", "y_axis")
      # move to the right and leave some space
      .attr("transform", "translate(#{@width - 15}, 0)")
      .call(@y_axis)

    # And finally draw the series
    #
    @svg.selectAll('path.serie')
      .data(stacked_data, (s) -> s.key)
      .enter().append('svg:path')
      .attr('class', 'serie')
      .attr('d', (d) => @area d.values)
      .style('fill', (d) => @colors d.key)

    @draw_legend(@svg, {series: @gqueries, offset: @series_height + 30})
    @rendered = true

  # Updates values
  #
  refresh: (data = {}) =>
    @render(data) unless @rendered
    # calculate tallest column
    tallest = @tallest_column_value(data)
    # update the scales as needed
    @y = @y.domain([0, tallest])
    @inverted_y = @inverted_y.domain([0, tallest])

    # animate the y-axis
    @svg.selectAll(".y_axis").transition().call(@y_axis.scale(@inverted_y))

    # and its grid
    @svg.selectAll('g.rule')
      .data(@y.ticks())
      .transition()
      .attr('transform', (d) => "translate(0, #{@inverted_y(d)})")

    # See above for explanation of this method chain
    stacked_data = @stack_method(@nest.entries @prepare_data(data))

    @svg.selectAll('path.serie')
      .data(stacked_data, (s) -> s.key)
      .transition()
      .attr('d', (d) => @area d.values)

  # The stack layout method needs data in a precise format
  prepare_data: (data) =>
    # We need to pass the chart series through the stacking function and the SVG
    # area function. To do this let's format the data as an array. An
    # interpolated mid-point is added to generate a S-curve.
    output = []
    left_stack  = 0
    mid_stack   = 0
    right_stack = 0
    # The mid point should be between the left and side value, which are
    # stacked
    for g in @gqueries
      present = data.results[g].present || 0
      future  = data.results[g].future || 0
      # let's calculate the mid point boundaries
      min_value = Math.min(left_stack + present, right_stack + future)
      max_value = Math.max(left_stack + present, right_stack + future)

      mid_point = if future > present then present else future
      mid_point += mid_stack

      mid_point = if mid_point < min_value
        min_value
      else if mid_point > max_value
        max_value
      else
        mid_point
      # the stacking function wants the non-stacked values
      mid_point -= mid_stack

      mid_stack   += mid_point
      left_stack  += present
      right_stack += future

      mid_year = (@start_year + @end_year) / 2

      output.push [
        {
          x: @start_year
          y: present
          id: g
        },
        {
          x: mid_year
          y: mid_point
          id: g
        },
        {
          x: @end_year
          y: future
          id: g
        }
      ]
    @flatten output

