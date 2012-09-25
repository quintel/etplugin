root = global ? window

TEST_ETENGINE_URL = 'http://localhost:3000'

if require?
  # Code for running tests on command line
  assert     = require("assert")
  Etmodel    = require('../vendor/assets/javascripts/jquery.etmodel.js').Etmodel
  ApiGateway = require('../vendor/assets/javascripts/jquery.etmodel.js').ApiGateway
else
  # Includes for running tests in a browser
  Etmodel    = root.Etmodel
  ApiGateway = root.ApiGateway
  assert     = root.assert

if $? # Run only if jquery is included. e.g. not when running it on a console.
  describe "$().etmodel()", ->
    before ->
      # -- mock api calls ---------------
      @etm = $('#scenario1').etmodel()[0]
      @etm.__call_api__ = ->

    it "should assign default settings", ->
      @etm_default = $('#scenario-defaults').etmodel()[0]
      assert.equal 'nl',   @etm_default.scenario.area_code
      assert.equal '2050', @etm_default.scenario.end_year

    it "should overwrite settings", ->
      assert.equal 'de',   @etm.scenario.area_code
      assert.equal '2030', @etm.scenario.end_year

    it "should find inputs and outputs", ->
      assert.equal 2,      @etm.inputs.length
      assert.equal 2,      @etm.outputs.length

    it "should assign api_path correctly", ->
      etm = $('#scenario1').etmodel({api_path: 'http://beta.et-engine.com'})[0]
      assert.equal 'http://beta.et-engine.com/api/v3/', etm.api.path('')

  describe 'integration', ->
    before ->

    it "when you change a slider it call before and afterLoading", (done) ->
      @etm = $('#scenario1').etmodel({
        beforeLoading: (-> done()),
        afterLoading:  (-> done())
      })[0]
      $(@etm.inputs[0]).trigger('change')
      done()


describe 'ApiGateway', ->
  # ----- api_path ------------------------------------------------------------

  make_api = (url) ->
    new ApiGateway({api_path: url})

  describe '#__apply_settings__', ->
    api = make_api TEST_ETENGINE_URL
    api.__apply_settings__({id: 212})
    assert.equal 212, api.scenario_id

    api.__apply_settings__({scenario_id: 213})
    assert.equal 213, api.scenario_id

    # scenario_id takes precedence
    api.__apply_settings__({scenario_id: 214, id: 215})
    assert.equal 214, api.scenario_id



  describe 'api_path', ->
    it "should assign api_path correctly and catch commong mistakes", ->
      assert.equal 'http://beta.et-engine.com/api/v3/', make_api('http://beta.et-engine.com').path('')
      assert.equal 'http://etengine.dev/api/v3/',  make_api('http://etengine.dev/').path('')
      assert.equal 'http://etengine.dev/api/v3/',  make_api('etengine.dev/').path('')
      assert.equal 'https://etengine.dev/api/v3/', make_api('https://etengine.dev/').path('')

    it "can only call setPath ones", ->
      api = new ApiGateway({api_path: 'http://beta.et-engine.com'})
      api.setPath('http://www.et-engine.com/')
      assert.equal 'http://beta.et-engine.com/api/v3/', api.path('')

    it "should flag isBeta if it's beta server", ->
      assert.equal true,  make_api('http://beta.et-engine.com').isBeta
      assert.equal false, make_api('http://www.et-engine.com').isBeta
      assert.equal false, make_api('http://etengine.dev').isBeta

    it "assigns default options to scenario", ->
      api = new ApiGateway()
      assert.equal null, api.scenario_id
      assert.equal false, api.opts.offline

    it "overwrites default options", ->
      api = new ApiGateway({
        scenario_id: 1234,
        offline: true
      })
      assert.equal 1234, api.scenario_id
      assert.equal true, api.opts.offline

    describe 'cors support', ->
      after  -> jQuery.support.cors = true

      it "always use proxy when cors = false", ->
        jQuery.support.cors = false
        assert.equal '/ete/api/v3/', new ApiGateway({api_path: 'ete.dev', offline: true}).path('')
        assert.equal '/ete/api/v3/', new ApiGateway({api_path: 'ete.dev', offline: false}).path('')

      it "when cors = true use proxy only when offline", ->
        jQuery.support.cors = true
        assert.equal '/ete/api/v3/',    new ApiGateway({api_path: 'ete.dev', offline: true}).path('')
        assert.notEqual '/ete/api/v3/', new ApiGateway({api_path: 'ete.dev', offline: false}).path('')


  describe "API on #{TEST_ETENGINE_URL}", ->
    before ->
      @api = new ApiGateway({api_path: TEST_ETENGINE_URL})

    it "#ensure_id() fetches new id", (done) ->
      api = @api
      api.ensure_id().done (id) ->
        assert.equal true, typeof id is 'number'
        assert.equal id, api.scenario_id
        done()

    it "#update queries: ['foo_demand'])", (done) ->
      @api.ensure_id().done (id) =>
        @api.update
          queries: ['foo_demand']
          success: (data) ->
            assert.equal true, typeof data.results.foo_demand.present is 'number'
            done()

    it "#update settings: use_fce", (done) ->
      @api.update
        settings: {use_fce: 1}
        queries: ['fce_enabled']
        success: ({results,inputs,scenario}) ->
          assert.equal(results.fce_enabled.future, 1)
          done()

    it "#update inputs: foo_demand with valid number updates future demand by that number", (done) ->
      @api.update
        inputs: {'foo_demand': 3.0}
        queries: ['foo_demand']
        success: (data) ->
          assert.ok(data)
          done()

    it "#update success: callback gets {results,inputs,settings}", (done) ->
      @api.update
        inputs: {'foo_demand': 3.0}
        queries: ['foo_demand']
        success: ({results,inputs,scenario}) ->
          assert.ok results
          assert.ok results.foo_demand
          assert.ok inputs
          assert.ok scenario
          done()

    it "#update inputs: foo_demand with valid number updates future demand by that number", (done) ->
      @api.update
        inputs: {'foo_demand': 3.0}
        queries: ['foo_demand']
        success: (data) ->
          assert.ok(data)
          done()

    it "#update inputs: foo_demand with invalid number calls the supplied error callback", (done) ->
      @api.update
        inputs: {'foo_demand': -1.0}
        error: (data) ->
          # TODO: error should return an array of error messages
          assert.ok data
          done()
        success: (data) ->
          assert.ok false
          done()

    it "#user_values returns values", (done) ->
      @api.user_values
        success: (inputs) ->
          assert.ok(inputs)
          # min/max should always be true (and never break :-)
          assert.ok inputs.foo_demand.min < inputs.foo_demand.max
          done()

    it "#changeScenario: from default end_year to 2030, also changes scenario_id", (done) ->
      api = @api
      previous_scenario_id = @api.scenario_id
      api.changeScenario
        attributes: {end_year: 2030}
        success: (data) ->
          assert.equal 4, arguments.length # also contains the original params
          assert.equal 2030, api.scenario.end_year
          assert.equal 2030, data.scenario.end_year
          # It changes scenario_id.
          assert.notEqual previous_scenario_id, data.scenario.id
          assert.notEqual previous_scenario_id, api.scenario_id
          done()


    it "#resetScenario: with a preset_scenario. Will reset all inputs.", (done) ->
      api = new ApiGateway({api_path: TEST_ETENGINE_URL, preset_scenario_id: 2999})

      previous_scenario_id = null
      api.ensure_id().done (id) ->
        previous_scenario_id = api.scenario_id

      api.user_values
        success: (data) ->
          # make sure we work with correct data: preset_scenario_id
          assert.equal 10, data.foo_demand.user

          api.resetScenario
            success: (data) ->
              assert.equal 4, arguments.length # also contains the original params
              assert.ok    data.inputs
              assert.ok    data.results
              assert.equal previous_scenario_id, data.scenario.id

              # scenario has been reset, now check that user_values have changed too:
              api.user_values
                success: (data) ->
                  assert.notEqual 10, data.foo_demand.user
                  done()

    describe 'error callbacks for', ->
      before ->
        @api = new ApiGateway({api_path: TEST_ETENGINE_URL})

      it "#user_values", (done) ->
        @api.ensure_id().done (id) =>
          @api.scenario_id = undefined
          @api.user_values
            error: (data) ->
              assert.ok(data)
              done()

      xit "#changeScenario", (done) ->
        # xitted for now, found no easy way to make an error
        @api.ensure_id().done (id) =>
          @api.scenario_id = undefined
          @api.changeScenario
            attributes: {end_year: 2000}
            success: (data) ->
              assert.ok false
              done()
            error: (data) ->
              assert.ok true
              done()


describe 'Etmodel.ResultFormatter', ->
  # format_result( 1.23455, 'round')
  format_result = (value, format) ->
    new Etmodel.ResultFormatter(value, format).value()

  # Shortcut to mimick a result set.
  result = (present, future) ->
    {present: present, future: future}

  before ->
    @res = result(10,15)

  it "should round future value by default", ->
    assert.equal(2.1,    format_result(result(0,2.1234)) )

  it "should round", ->
    assert.equal(1.2,    format_result(1.234, 'round') )
    assert.equal(1.0,    format_result(1.234, 'round:0') )
    assert.equal(1.2,    format_result(1.234, 'round:1') )
    assert.equal(1.23,   format_result(1.234, 'round:2') )
    assert.equal(1230.0, format_result(1234.234, 'round:-1') )

  it "should fetch present|future", ->
    assert.equal(10,     format_result(@res, 'present') )
    assert.equal(15,     format_result(@res, 'future') )

  it "should calculate delta", ->
    assert.equal((15/10)-1, format_result(@res, 'delta') )
    assert.equal(0,      format_result(result(0,0), 'delta') )

  it "should chain format strings", ->
    assert.equal(0.5,    format_result(@res, 'delta') )
    assert.equal(50,     format_result(@res, 'delta;percent') )
    assert.equal(28.6,   format_result(result(7,9), 'delta;percent;round:1') )
