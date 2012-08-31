root = global ? window

if require?
  assert  = require("assert")
  Etmodel = require('../vendor/assets/javascripts/jquery.etmodel.js').Etmodel
else
  Etmodel = root.Etmodel
  assert = root.assert

format_result = (value, format) ->
  new Etmodel.ResultFormatter(value, format).value()

result = (present, future) ->
  {present: present, future: future}

describe 'Etmodel.ResultFormatter', ->
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
