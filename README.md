## ET-Plugin

Build your own small energy future scenario or make an interactive infographic
on Energy, using the renowed Energy Transition Model. Free for use!

## Installation

ET-Plugin is a jQuery plugin. Make sure you use jQuery 1.6+ and add this plugin
to your site:

    <head>
      <script type<script src="jquery.js" type="text/javascript"></script>
      <script type<script src="jquery.etplugin.js" type="text/javascript"></script>
    </head>

Then you can start using user variables on any plain form objects, such as:

### Input field

    <form>
      <input type='textfield' name='your_name' class='etm_population_growth'/>
    </form>

### Select fields

...

### Radio buttons

...

## Output

You can add the outcome of the ETM to your

### Div

    <div class=etm_total_co2_emissions></div>

### Span

...

### Chart

...

## Customizing

### ApiGateway

You can access our API, through the ApiGateway class.

ApiGateway connects to the etengine gateway and does all the necessary checks.

#### Basic usage

    api = new ApiGateway()
    api.update
      inputs:  {households_number_of_inhabitants: -1.5}
      queries: ['dashboard_total_costs']
      success: (result) ->
        console.log(result.queries.dashboard_total_costs.future)
      error: -> alert("error")

Add before/afterLoading callbacks, for example to show a "Loading..." message to the user.

    api = new ApiGateway
      beforeLoading: -> console.log('before')
      afterLoading:  -> console.log('after')

The API needs a scenario_id that keeps track of the settings of a user. A scenario is similar to a session, in that it persists over multiple requests and page refreshes.

    api = new ApiGateway()
    # At this moment there is no scenario_id defined:
    api.scenario_id # => null

Every functionality that needs a scenario\_id, you have to wrap it inside a ensure\_id().done (id) -> function. This is an async request.

    api.ensure_id().done (id) ->
      alert(id) # => 32311
      alert(api.scenario_id) # => 32311

You can manually keep track of a users scenario_id, for example in a cookie variable, and then pass it to the ApiGateway constructor as an option:

    api = new ApiGateway(scenario_id: 323231)

#### Updating

When a user makes a change, the new values have to be sent to the API.

    api.update
      inputs: {households_number_of_inhabitants: -1.5}
      success: -> console.log('success')

In the same request we can define queries that should be returned:

    api.update
      inputs: {households_number_of_inhabitants: -1.5}
      queries: ['dashboard_total_costs']
      success: (data) -> console.log(data.results.dashboard_total_costs)
    # => {present: 23, future: 32}


#### Get slider values (start,min,max)

    api.user_values(success: (data) -> console.log(data) )

### Error handling

...

# Issues

Please post any issues on [our Issue list](http://github.com/dennisschoenmakers/etplugin/issues)
