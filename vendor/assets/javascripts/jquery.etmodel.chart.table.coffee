root = global ? window

class root.Table extends root.BaseChart
  constructor: (container, gqueries) ->
    super(container, gqueries)

  render: (data, values) =>
    start_year = 2010
    end_year   = data.scenario.end_year

    table = d3.select(@container).append('table').attr('class', 'etm-d3')
    thead = table.append('thead')
    tbody = table.append('tbody')

    # Table header
    #
    thead.append('tr')
      .selectAll('th')
      .data([null, start_year, end_year])
      .enter()
      .append('th')
      .text((d) -> d)

    @rows = tbody.selectAll('tr.d3-row')
      .data(values, (d) -> d.key)
      .enter()
      .append('tr')
      .attr('class', 'd3-row')

    @rows.append('th').text((d) => @humanize_string d.key)
    @rows.append('td').attr('class', 'present')
    @rows.append('td').attr('class', 'future')

    @rendered = true

  # Updates values
  #
  refresh: (data = {}) =>
    values = @prepare_data(data)
    @render(data, values) unless @rendered
    @rows.data(values, (d) -> d.key)
    @rows.select('td.future').text((d) -> d.future)
    @rows.select('td.present').text((d) -> d.present)

  # Converts the hash into an array of hashes
  prepare_data: (data) ->
    out = []
    for key, values of data.results
      out.push
        key: key
        present: values.present
        future: values.future
    out

