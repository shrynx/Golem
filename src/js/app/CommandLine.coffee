React = require 'React'
{_div} = hyper = require 'hyper'

$ = require 'ejquery'
ace = require 'ace/ace'

Timeline = require './UniqueTimeline'
CommandMode = require './CommandMode'

module.exports = hyper class CommandLine

  propTypes:
    timeline: React.PropTypes.object.isRequired
    onCommandExecution: React.PropTypes.func.isRequired
    onCommandFailed: React.PropTypes.func.isRequired

  getInitialState: ->
    backgroundColor: '#222'

  handleMouseEnter: ->
    @state.editor.focus()

  _getEditorNode: ->
    @refs.ace.getDOMNode()

  _setMode: (sourceMode) ->
    @state.editor.session.setMode new CommandMode "compilers/#{sourceMode}"

  componentWillReceiveProps: ({focus, sourceMode}) ->
    if focus
      @state.editor.focus()
    if sourceMode and sourceMode isnt @props.sourceMode
      @_setMode sourceMode

  componentDidMount: ->
    editor = ace.edit @_getEditorNode()
    editor.setTheme "ace/theme/cobalt"
    editor.setHighlightActiveLine false
    editor.setShowPrintMargin false
    editor.renderer.setShowGutter false

    editor.renderer.on 'themeLoaded', =>
      @setState backgroundColor: $(@_getEditorNode()).css 'background-color'

    editor.commands.addCommand
      name: 'execute'
      bindKey: win: 'Enter', mac: 'Enter'
      exec: ->
        editor.session.getMode().updateWorker()

    timeline = @props.timeline

    editor.commands.addCommand
      name: 'previous'
      bindKey: win: 'Up', mac: 'Up'
      exec: ->
        timeline.temp editor.getValue() unless timeline.isInPast()
        editor.setValue timeline.goBack()
        editor.clearSelection()

    editor.commands.addCommand
      name: 'following'
      bindKey: win: 'Down', mac: 'Down'
      exec: ->
        editor.setValue timeline.goForward() if timeline.isInPast()
        editor.clearSelection()

    editor.commands.addCommand
      name: 'leave'
      bindKey: win: 'Esc', mac: 'Esc'
      exec: @props.onLeave

    editor.session.on 'changeMode', =>
      commandWorker = editor.session.getMode().worker

      # CommandWorker only compiles on user enter, hence this is an order to execute
      # the source and the command
      commandWorker.on 'ok', ({data: {result, type}}) =>
        # TODO use prelude trim
        source = $.trim editor.getValue()
        if source.length > 0
          timeline.push source
          @props.onCommandExecution result
          editor.setValue ""

      commandWorker.on 'error', ({data: {text}}) =>
        @props.onCommandFailed text

    @setState
      editor: editor

    @_setMode @props.sourceMode

  render: ->
    # This wrapper is required for mouseEnter triggering
    _div onMouseEnter: @handleMouseEnter,
      _div
        className: 'areaBorder'
        style: backgroundColor: @state.backgroundColor,
        _div ref: 'ace', style: width: '100%', height: 17