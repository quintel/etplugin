## ET-Plugin

Build your own small energy future scenario or make an interactive infographic
on Energy, using the renowed Energy Transition Model. Free for use!

## Installation Gem:

Gemfile:

    gem "jquery-etmodel-rails", :git  => "git@github.com:dennisschoenmakers/etplugin"

app/assets/javascripts/application.js

    // require jquery.etmodel

If you want to work on the plugin itself, clone this repository and replace the above with the following command:

    gem "jquery-etmodel-rails", :path => "~/path/to/etplugin"

Change files and reload:

    etmodel $ bundle install
    etmodel $ rails s

For big changes it might be worthwile to copy the file into app/assets/javascripts and then when everything is working, copy it back.


### Installation (standalone)

Copy the jquery.etmodel.js file from the vendor/assets/javascripts folder.

ET-Plugin is a jQuery plugin. Make sure you use jQuery 1.6+ and add this plugin
to your site:

    <head>
      <script type<script src="jquery.js" type="text/javascript"></script>
      <script type<script src="jquery.ajaxqueue.js" type="text/javascript"></script>
      <script type<script src="jquery.etmodel.js" type="text/javascript"></script>
    </head>

Then you can start using user variables on any plain form objects.


## ApiGateway

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



## Testing


Tests are written using the mocha testing framework (http://visionmedia.github.com/mocha/).

Installing mocha:

    $ npm install -g mocha

Running tests on console (excl. jquery tests).

    $ mocha test/

To run tests in the browser it is easiest to set up an own "server" using pow:

### Opening tests and example files with Pow

Easiest is to create symlink inside your etplugin folder to itself.

    $ ln -s /path/to/quintel/etplugin public

Check that ls -lh looks like this:

    $ ls -lh
    ...
    lrwxr-xr-x  1 seb  staff    28B Sep  3 15:41 public -> /Users/seb/quintel/etplugin/
    ...

Then add your etplugin to Pow:

    $ ln -s /path/to/quintel/etplugin/ /path/to/.pow/etplugin

Now open your browser:

    http://etplugin.dev/test/test.html

To make the integration tests work we need to start up a separate etengine server with the etengine/spec/fixtures/etsource loaded. This etsource fixture makes it easy and fast to reliably test features.

Start etengine rails server

    $ cd /path/to/etengine
    $ ETSOURCE_DIR=spec/fixtures/etsource rails s

Reload `http://etplugin.dev/test/test.html` and the tests should now pass.


### Error handling

...


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

### Charts

The plugin is able to render charts on all browsers that support the [D3.js](http://d3js.org/) javascript library. You have to add to your code an HTML element like this:

    <div data-etm-chart-type="TYPE" data-etm-chart-series="SERIES"></div>

With `TYPE` being one of

* bezier
* stacked_bar
* table

The `SERIES` parameter is a list of the series to be plotted, separated by a comma.

Here is a valid example:

    <div data-etm-chart-type="stacked_bar" data-etm-chart-series="total_co2_emissions,co2_emissions_of_imported_electricity,co2_emissions_of_used_electricity"></div>
## Customizing

# Issues

Please post any issues on [our Issue list](http://github.com/dennisschoenmakers/etplugin/issues)
