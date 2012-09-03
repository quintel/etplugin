root = global ? window

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
      ApiGateway.prototype.call_api = ->
      @etm = $('#scenario1').etmodel()[0]

    it "should assign default settings", ->
      @etmdefault = $('#scenario-defaults').etmodel()[0]
      assert.equal 'nl', @etmdefault.settings.area_code
      assert.equal '2050', @etmdefault.settings.end_year

    it "should overwrite settings", ->
      assert.equal 'de', @etm.settings.area_code
      assert.equal '2030', @etm.settings.end_year

    it "should find inputs", ->
      assert.equal 2, @etm.inputs.length


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
