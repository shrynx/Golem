Mirror = require("ace/worker/mirror").Mirror
oop = window.require("ace/lib/oop");
EventEmitter = require("ace/lib/event_emitter").EventEmitter

compiler = require "./compiler"

window.addEventListener = ->

# Must be kept in this export form for correct loading by Ace
exports.Worker = class extends Mirror
  constructor: (sender) ->
    super sender
    @setTimeout 20 # Take over the scheduling from Mirror
    # @trigger = delay 700

  setModuleName: (@moduleName) ->
    @validModuleName = moduleNameForCompiler @moduleName

  setFilePath: (@filePath) ->

  setExported: (@exported) ->

  compileModule: (value, moduleName, exported) ->
    @_compile value, moduleName, no, exported

  onUpdate: ->
    # @trigger @compile
    @compile()

  compile: =>
    value = @doc.getValue()
    @_compile value, @moduleName, yes, @exported

  _compile: (value, moduleName, current, exported) ->
    console.log "worker: compiling #{moduleName}, current: #{current}, exported: #{exported}"
    try
      result = cacheModule compiler.compileModuleTopLevel, value, moduleName, exported
      if result.request
        listening = @sender.on 'ok', (requested) =>
          if requested.moduleName is result.request
            @sender.off 'ok', listening
            @_compile value, moduleName, current
        @sender.emit "request", moduleName: result.request
      else
        @sender.emit "ok",
          result: result
          source: value
        @sender._emit "ok",
          moduleName: moduleName
    catch e
      console.log "error in source worker", e.message
      console.log e.stack
      @sender.emit "error",
        text: e.message
        type: 'error'
        source: value
        inDependency: not current

  methods:
    parseExpression: (source) ->
      compiler.parseExpression @validModuleName, source

    matchingDefinitions: (reference) ->
      compiler.findMatchingDefinitions @validModuleName, reference

    availableTypes: (inferredType) ->
      compiler.findAvailableTypes @validModuleName, inferredType

    docsFor: (reference) ->
      compiler.findDocsFor @validModuleName, reference

    expand: (expression) ->
      compiler.expand @validModuleName, expression

    compileBuild: (moduleName) ->
      compiler.compileModuleWithDependencies moduleNameToPath moduleName

# Returns a function which runs given function maximally once during given
# duration.
delay = (duration) ->
  timeout = undefined
  ready = true
  reset = (executed, fn) -> ->
    ready = true
    if not executed
      fn()
  (fn, force = no) ->
    clearTimeout timeout if timeout?
    run = ready or force
    if run
      fn()
    timeout = setTimeout (reset run, fn), duration
    ready = false

class AdhocWorker extends exports.Worker
  constructor: (sender) ->
    super sender
    @compilationFn = compiler.compileExpression

  onUpdate: (execute) ->
    value = @doc.getValue()

    if value[0] is ':'
      if execute
        @sender.emit "ok",
          result: value[1..]
          commandSource : value
          type: 'command'
    else if value isnt ''
      try
        console.log "expression worker compiling", @moduleName
        @sender.emit "ok",
          type: (if execute then 'execute' else 'normal')
          commandSource: value
          filePath: @filePath
          result:
            @compilationFn value, moduleNameToPath @moduleName, @exported

      catch e
        console.log e.stack
        console.log e
        @sender.emit "error",
          text: e.message
          type: 'error'
          commandSource: value
        return

  parseOnly: (isTopLevel) ->
    @compilationFn =
      if isTopLevel
        compiler.parseTopLevel
      else
        compiler.parseExpression

moduleNameForCompiler = (moduleName) ->
  if /\/index$/.test moduleName
    moduleName[0...-6]
  else
    moduleName

moduleNameToPath = (moduleName, exported) ->
  names = (moduleNameForCompiler moduleName).split '/'
  {names, types: ('browser' for _ in names), exported}

cache = {}

cacheModule = (fn, source, moduleName, exported) ->
  if (old = cache[moduleName])?.source is source and old and old.exported is exported
    console.log "#{moduleName} was cached."
    old.result
  else
    result = fn source, moduleNameToPath moduleName, exported
    if not result.request
      cache[moduleName] =
        source: source
        exported: exported
        result: result
    result

# Sender with specific id for duplicate workers
class Sender
  constructor: (@id) ->
    oop.implement this, EventEmitter

  callback: (data, callbackId) ->
    postMessage
      type: "call"
      identifier: @id
      id: callbackId
      data: data

  emit: (name, data) ->
    postMessage
      type: "event"
      identifier: @id
      name: name
      data: data

# Map of workers, excluding the original main worker
workers = {}
inheritedOnMessage = window.onmessage

# This overrides the default handler from ace/worker/worker.js
window.onmessage = (e) ->
  msg = e.data
  main = window.main
  sender = window.sender
  id = msg.identifier

  # check sender for global worker initialization
  if sender and id? or main and msg.command
    worker =
      if id?
        workers[id] ?= new AdhocWorker (new Sender id), msg
      else
        main
    if msg.command
      if worker.methods[msg.command]
        [..., id] = msg.args
        worker.sender.callback (worker.methods[msg.command].apply worker, msg.args), id
      else if worker[msg.command]
        worker[msg.command].apply(worker, msg.args)
      else
          throw new Error("Unknown command: " + msg.command)
    else if msg.event
      worker.sender._signal(msg.event, msg.data)
  else
    # Performs initialization of the main worker
    inheritedOnMessage e
