{_div, _pre, _span} = hyper = require 'hyper'

React = require 'React'
ace = require 'ace/ace'
jsDump = require 'vendor/jsDump'

{Mode} = require 'compilers/teascript/mode'

module.exports = hyper class UpdatingDisplay

  parseValue: (value) ->
    _pre {},
      if not value?
        "Nothing"
      else if typeof value is 'function'
        value.toString()
      else
        jsDump.parse value

  runSource: ->
    try
      result = eval @props.compiledSource + @props.compiledExpression
      @parseValue result
    catch error
      _span style: color: '#cc0000',
        "#{error}"

  handleCommand: (name) ->
    => @props.onCommand name, @editor

  componentDidMount: ->
    @editor = editor = ace.edit @refs.ace.getDOMNode(), new Mode, "ace/theme/tea"
    editor.setFontSize 13
    editor.renderer.setScrollMargin 2, 2
    editor.setHighlightActiveLine false
    editor.session.setTabSize 2
    editor.setShowPrintMargin false
    editor.renderer.setShowGutter false
    # editor.setReadOnly true
    editor.setValue @props.expression, 1
    editor.session.getMode().attachToSession editor.session

    for name, command of editor.session.getMode().commands
      command.exec = @handleCommand name

  render: ->
    _div id: @props.key, key: @props.key, className: 'log', style: 'max-width': @props.maxWidth,
      _div ref: 'ace', style: width: '100%', height: 22
      _div style: height: 0, margin: '0 4px', overflow: 'hidden', @props.expression
      _div style: padding: '0 4px', @runSource()