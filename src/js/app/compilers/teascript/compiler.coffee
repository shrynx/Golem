keywords = 'def defn data class fn proc match if type :: \\
            access call new
            require'.split ' '

controls = '\\(\\)\\[\\]\\{\\}'

tokenize = (input) ->
  whitespace = ''
  currentPos = 0
  while input.length > 0
    match = input.match ///
      ^ # must be at the start
      (
        \s+ # pure whitespace
      | [#{controls}] # brackets
      | /([^\ /]|\\/)([^/]|\\/)*?/ # regex
      | "[^"]*?" # strings
      | '\\?[^']' # char
      | [^#{controls}"'\s]+ # normal tokens
      )///
    if not match
      throw new Error "Could not recognize a token starting with `#{input[0..10]}`"
    [token] = match
    input = input[token.length...]
    if /\s+$/.test token
      whitespace = token
      continue
    ws = whitespace
    pos = currentPos
    currentPos += ws.length + token.length
    whitespace = ''
    {token, ws, pos}

leftDelims = ['(', '[', '{']
rightDelims = [')', ']', '}']

astize = (tokens) ->
  tree = []
  current = []
  stack = [[]]
  for token in tokens
    if token.token in leftDelims
      stack.push [token]
    else if token.token in rightDelims
      closed = stack.pop()
      closed.push token
      stack[stack.length - 1].push closed
    else
      stack[stack.length - 1].push token
  stack[0][0]

typed = (a, b) ->
  b.type = a.type
  b

walk = (ast, cb) ->
  if Array.isArray ast
    ast = cb ast
    if Array.isArray ast
      ast = typed ast, (for node in ast
        walk node, cb)
  ast

walkOnly = (ast, cb) ->
  if Array.isArray ast
    cb ast
    for node in ast
      walk node, cb
  ast

crawl = (ast, cb, parent) ->
  if Array.isArray ast
    typed ast, (for node in ast
      crawl node, cb)
  else
    cb ast, ast.token

crawlWhile = (ast, cond, cb) ->
  if Array.isArray ast
    if cond ast
      for node in ast
        crawlWhile node, cond, cb
  else
    cb ast, ast.token
  return

inside = (node) -> node[1...-1]

matchNode = (to, node) ->
  return false unless node.length >= 3
  [paren, {token}] = node
  paren.token is '(' and token is to

matchAnyNode = (tos, node) ->
  for to in tos
    if matchNode to, node
      return true
  return false

macro = (operator, ast, cb) ->
  walk ast, (node) ->
    if matchNode operator, node
      return cb node, inside node
    node

typedMacro = (type, ast, cb) ->
  walk ast, (node) ->
    if node.type is type
      return cb node, inside node
    node

mapTokens = (tokens, ast, cb) ->
  crawl ast, (word, token) ->
    if token in tokens
      cb word

theme =
  keyword: 'red'
  numerical: '#FEDF6B'
  typename: '#9C49B6'
  label: '#9C49B6'
  string: '#FEDF6B'
  paren: '#444'
  name: '#9EE062'
  recurse: '#67B3DD'
  param: '#FDA947'
  comment: 'grey'
  operator: '#cceeff'
  normal: 'white'

colorize = (color, string) ->
  "<span style=\"color: #{color}\">#{string}</span>"

labelMapping = (word, rules...) ->
  for [label, cond] in rules when cond
    word.label = label
    return word
  word

labelSimple = (ast) ->
  crawl ast, (word, token) ->
    labelMapping word,
      ['keyword', token in keywords]
      ['numerical', /^-?\d+/.test(token)]
      #['typename', /^[A-Z]/.test token]
      ['label', /^[^\s]*:$/.test token]
      ['const', /^;[^\s]*$/.test token]
      ['string', /^["']/.test token]
      ['regex', /^\/[^ \/]/.test token]
      ['paren', token in ['(', ')']]
      ['bracket', token in ['[', ']']]
      ['brace', token in ['{', '}']]
      ['bare', true]

isDelim = (token) ->
  /[\(\)\[\]\{\}]/.test token.token

labelMatches = (ast) ->
  macro 'match', ast, (node, args) ->
    [keyword, over, patterns...] = args
    for pattern in patterns by 2
      labelNames pattern
    node

isReference = (token) ->
  token.label in ['bare', 'operator', 'param', 'recurse'] and not isDelim token

fnDefinition = (node) ->
  words = inside node
  [keyword, paramList, defs...] = words
  params = if Array.isArray(paramList) then paramList else undefined
  defs ?= []
  for def, i in defs
    if matchNode '::', def
      type = def
    else if matchNode '#', def
      doc = def
    if not matchAnyNode ['::', '#'], def
      implementation = defs[i...]
      break
  {body, wheres} = fnImplementation implementation ? []
  {params, type, doc, body, wheres}

fnImplementation = (defs) ->
  [body, where...] = defs
  wheres = whereList where
  {body, wheres}

bottomImplementation = (defs) ->
  [where..., body] = defs
  wheres = whereList where
  {body, wheres}

whereList = (defs) ->
  pairs defs

pairs = (list) ->
  for el, i in list by 2
    [el, list[i + 1]]

labelTop = (ast) ->
  {wheres} = fnImplementation inside ast
  labelWhere wheres
  ast

labelBottom = (ast) ->
  {wheres} = bottomImplementation inside ast
  labelWhere wheres
  ast

labelDefinitions = (ast) ->
  labelWhere whereList inside ast
  ast

labelFns = (ast) ->
  macro 'fn', ast, (node, args) ->
    node.type = 'function'
    {params, body, wheres} = fnDefinition node
    labelFnBody body
    labelWhere wheres
    labelParams node, params if params?
    node

labelFnBody = (node) ->
  return

labelNames = (pattern) ->
  if Array.isArray pattern
    if isList(pattern) or isTuple pattern
      pattern.type = 'pattern'
      (inside pattern).map labelNames
    else
      [op, args...] = inside pattern
      args.map labelNames
  else
    pattern.label = 'name' if pattern.label is 'bare'

labelWhere = (wheres) ->
  for [name, def] in wheres
    labelNames name
    if def
      if matchNode 'fn', def
        labelRecursiveCall def, name.token
  return

labelParams = (ast, params) ->
  params.type = 'pattern'
  paramNames = (token for {token} in inside params)
  mapTokens paramNames, ast, (word) ->
    word.label = 'param' if isReference word

labelRecursiveCall = (ast, fnname) ->
  mapTokens [fnname], ast, (word) ->
    word.label = 'recurse' if word.label isnt 'param'

# Ideally shouldnt have to, just doing it to get around the def checking
labelRequires = (ast) ->
  macro 'require', ast, (node, words) ->
    [req, module, list] = words
    module.label = 'symbol'
    for fun in inside list
      fun.label = 'symbol'
    node

typeDatas = (ast) ->
  macro 'data', ast, (node) ->
    node.type = 'data'
    node

typeTypes = (ast) ->
  macro '::', ast, (node) ->
    node.type = 'type'
    node

typeComments = (ast) ->
  macro '#', ast, (node) ->
    node.type = 'comment'
    node

labelComments = (ast) ->
  typedMacro 'comment', ast, (node, words) ->
    for word in words
      word.label = 'comment' unless word.label in ['param', 'recurse']
    node

labelOperators = (ast) ->
  walk ast, (node) ->
    [openDelim, operator] = node
    if openDelim.token is '('
      if not operator.type and operator.label is 'bare'
        operator.label = 'operator'
    else if node.type isnt 'pattern'
      [openDelim, ..., closeDelim] = node
      openDelim.label = 'operator'
      closeDelim.label = 'operator'
    node

apply = (onto, fns...) ->
  result = onto
  for fn in fns
    result = fn result
  result

typifyMost = (ast) ->
  apply ast, typeComments, typeDatas, typeTypes, labelSimple, labelMatches, labelFns, labelRequires

typify = (ast) ->
  apply ast, typifyMost, labelComments, labelOperators

typifyTop = (ast) ->
  apply ast, typifyMost, labelTop, labelComments, labelOperators

typifyBottom = (ast) ->
  apply ast, typifyMost, labelBottom, labelComments, labelOperators

typifyDefinitions = (ast) ->
  apply ast, typifyMost, labelDefinitions, labelComments, labelOperators

toHtml = (highlighted) ->
  crawl highlighted, (word) ->
    (word.ws or '') + colorize(theme[word.label ? 'normal'], word.token)

# Correct offset by 1 in positions, when we wrap the source in an S-exp
shiftPos = (ast) ->
  crawl ast, (word) ->
    word.pos = word.pos - 1
    word

parentize = (highlighted) ->
  walkOnly highlighted, (node) ->
    for subNode in node
      subNode.parent = node
    node

collapse = (nodes) ->
  collapsed = ""
  for node in nodes
    crawl node, (node) ->
      collapsed += node
  collapsed

syntaxed = (source) ->
  collapse inside toHtml typifyTop astize tokenize "(#{source})"

syntaxedExp = (source) ->
  collapse toHtml typify astize tokenize source

tokenizedDefinitions = (source) ->
  (parentize shiftPos [inside typifyDefinitions astize tokenize "(#{source})"])[0]

tokenizedExp = (source) ->
  parentize typify astize tokenize source

variableCounter = 1
warnings = []
nonstrict = no

# exp followed by list of definitions
compiled = (source) ->
  variableCounter = 1
  compileTop preCompileTop source

# list of definitions followed by an expression, returns only
# the expression part
compiledBottom = (source) ->
  variableCounter = 1
  warnings = []
  nonstrict = yes
  [(compileBottom preCompileBottom source), warnings]

# single exp
compiledExp = (source) ->
  variableCounter = 1
  warnings = []
  nonstrict = yes
  "(#{compileSingleExp preCompileExp source})"

# list of definitions
compileDefinitions = (source) ->
  variableCounter = 1
  compileWheres preCompileDefs source

# exported list of definitions
compileDefinitionsInModule = (source) ->
  variableCounter = 1
  compileWheresInModule preCompileDefs source

exportList = (source) ->
  wheres = whereList inside preCompileDefs source
  names = []
  for [pattern] in wheres
    if pattern.token and pattern.token isnt '_'
      names.push pattern.token
  names

preCompileExp = (source) ->
  parentize typify astize tokenize source

preCompileBottom = (source) ->
  parentize typifyBottom astize tokenize "(#{source})"

preCompileTop = (source) ->
  parentize typifyTop astize tokenize "(#{source})"

preCompileDefs = (source) ->
  parentize typifyDefinitions astize tokenize "(#{source})"

compileSingleExp = (ast) ->
  ast.scope = topScopeDefines()
  compileImpl ast

compileTop = (ast) ->
  ast.scope = topScopeDefines()
  {body, wheres} = fnImplementation inside ast
  compileFnImpl body, wheres

compileBottom = (ast) ->
  ast.scope = topScopeDefines()
  {body, wheres} = bottomImplementation inside ast
  [wheresDef, bodyDef] = compileFnImplParts body, wheres
  bodyDef

compileWheres = (ast) ->
  ast.scope = topScopeDefines()
  (compileWhereImpl inside ast).map(compileDef).join '\n'

compileWheresInModule = (ast) ->
  ast.scope = topScopeDefines()
  (compileWhereImpl inside ast).map(compileExportedDef).join '\n'

compileWhereImpl = (tokens) ->
  if tokens.length % 2 != 0
    throw new Error "missing definition in top level assignment"
  [readyWheres, hoistableWheres] = wheresWithHoisting whereList tokens
  if hoistableWheres.length > 0
    undefinedNames = []
    for {missing} in hoistableWheres
      undefinedNames.push (setToArray missing)...
    throw new Error "#{undefinedNames.join ', '} used but not defined"
  addToScopeAllNames readyWheres
  graphToWheres readyWheres

compileExportedDef = ([name, def]) ->
  if name.token
    identifier = validIdentifier name.token
    # ignore _s for now
    if identifier is '_'
      ''
    else
      "var #{identifier} = exports['#{identifier}'] = #{compileImpl def};"
  else
    compileDef [name, def]

compileImpl = (node, hoistableWheres = []) ->
  # For now special case match to allow definition hoisting up one level
  if matchNode 'match', node
    [op, args...] = inside node
    return trueMacros[op.token] hoistableWheres, args...

  switch node.type
    when 'comment' then 'null'
    when 'data' then 'null'
    when 'type' then 'null'
    when 'function'
      compileFn node
    else
      if Array.isArray node
        exps = inside node
        if isMap node
          compileMap exps
        else if isTuple(node) or isList(node)
          compileList exps
        else
          [op, args...] = exps
          if op
            opName = op.token
            if opName and expander = trueMacros[opName]
              expander args...
            else if opName and expander = macros[opName]
              expander (args.map compileImpl)...
            else
              compileFunctionCall op, args
      else if node.label is 'const'
        compileConst node
      else if node.label is 'regex'
        node.token
      else
        name = node.token
        if macros[name]
          expandMacro name
        else
          [firstChar] = name
          if firstChar is '-'
            "(- #{validIdentifier name[1...]})"
          else if firstChar is '/'
            # regex
            name
          else
            escapedName = validIdentifier name
            if isReference node
              defLocation = lookupIdentifier name, node
              if not defLocation
                if nonstrict
                  warnings.push "#{name} used but not defined"
                else
                  throw new Error "#{name} used but not defined"
            escapedName

isList = (node) ->
  Array.isArray(node) and node[0].token is '['

isTuple = (node) ->
  Array.isArray(node) and node[0].token is '{'

isMap = (node) ->
  isTuple(node) and (elems = inside node; elems.length > 0) and elems[0].label is 'label'

compileMap = (elems) ->
  [constr, args...] = elems
  items = args.map(compileImpl).join ', '
  "({\"#{constr.token}\": [#{items}]})"

compileConst = (token) ->
  "({'#{token.token}': true})"

compileList = (elems) ->
  # "[#{elems.join ', '}]"
  "[#{elems.map(compileImpl).join ', '}]"

compileFunctionCall = (op, args) ->
  fn = compileImpl op
  # Ignore labels for now
  params = for arg in args when arg.label isnt 'label'
    compileImpl arg
  "#{fn}(#{params.join ', '})"

expandMacro = (macro) ->
  macros[macro]?() ? macro

validIdentifier = (name) ->
  [firstChar] = name
  if firstChar is '-'
    throw new Error "Identifier expected, but got minus #{name}"
  else if firstChar is '/'
    throw new Error "Identifier expected, but found regex #{name}"
  else
    name
      .replace(/\+/g, 'plus_')
      .replace(/\-/g, '__')
      .replace(/\*/g, 'times_')
      .replace(/\//g, 'over_')
      .replace(/\√/g, 'sqrt_')
      .replace(/\./g, 'dot_')
      .replace(/\&/g, 'and_')
      .replace(/\?/g, 'p_')
      .replace(/^const$/, 'const_')
      .replace(/^default$/, 'default_')
      .replace(/^with$/, 'with_')
      .replace(/^in$/, 'in_')

lookupIdentifier = (name, node) ->
  while node.parent
    node = node.parent
    if node.scope and name of node.scope
      return node
  null

addToEnclosingScope = (name, node) ->
  while node.parent
    node = node.parent
    if node.scope
      node.scope[name] = true
      return
  throw new Error "Defining #{name} without enclosing scope"

compileFn = (node) ->
  {params, body, wheres} = fnDefinition node
  if !params?
    throw new Error 'missing parameter list'
  paramNames = (inside params).map getToken
  node.scope = toMap paramNames
  validParamNames = paramNames.map validIdentifier
  curry validParamNames, """
    (function (#{validParamNames.join ', '}) {
      #{compileFnImpl body, wheres, yes}
    })"""

curry = (paramNames, fnDef) ->
  if paramNames.length > 1
    """$curry#{fnDef}"""
  else
    fnDef

toMap = (array) ->
  map = {}
  for x in array
    map[x] = true
  map

getToken = (word) -> word.token

compileFnImpl = (body, wheres, doReturn) ->
  [wheresDef, bodyDef] = compileFnImplParts body, wheres
  [
    wheresDef
  ,
    if doReturn
      "return #{bodyDef};"
    else
      bodyDef
  ].join '\n'

compileFnImplParts = (body, wheres) ->
  if not body
    throw new Error "Missing definition of a function"
  # Find invalid (hoistable) wheres and let the function body
  # define them
  if (unpairs wheres).length % 2 != 0
    throw new Error "Missing definition for last assignement inside function"
  [readyWheres, hoistableWheres] = wheresWithHoisting wheres
  addToScopeAllNames readyWheres
  wheresDef = (graphToWheres readyWheres).map(compileDef).join '\n'
  bodyDef = compileImpl body, hoistableWheres
  [wheresDef, bodyDef]

unpairs = (pairs) ->
  unpaired = []
  for [a, b] in pairs
    unpaired.push a if a?
    unpaired.push b if b?
  unpaired

addToScopeAllNames = (graph) ->
  for {names, def: [pattern, def]} in graph
    for name in names
      addToEnclosingScope name, def
  return

wheresWithHoisting = (wheres) ->
  graph = constructDependencyGraph wheres
  [hoistableGraph, readyGraph] = findHoistableWheres graph
  [
    sortTopologically readyGraph
    sortTopologically hoistableGraph
  ]

graphToWheres = (graph) ->
  graph.map ({def: [pattern, def], missing}) -> [pattern, def, missing]

# Returns two new graphs, one which needs hoisting and one which doesnt
findHoistableWheres = ([graph, lookupTable]) ->
  reversedDependencies = reverseGraph graph
  hoistableNames = {}
  hoistable = []
  valid = []
  for {missing, names} in graph
    # This def needs hoisting
    if missing.numDependencies > 0
      hoistableNames[n] = yes for n in names
      # So do all defs depending on it
      for name in names
        for dep in (reversedDependencies[name] or [])
          for n in dep.names
            hoistableNames[n] = yes
  for where in graph
    {names} = where
    hoisted = no
    for n in names
      # if one of the names needs hoisting
      if hoistableNames[n]
        hoistable.push where
        hoisted = yes
        break
    if not hoisted
      valid.push where
  [
    [hoistable, lookupTableForGraph hoistable]
    [valid, lookupTableForGraph valid]
  ]

sortTopologically = ([graph, dependencies]) ->
  reversedDependencies = reverseGraph graph
  independent = []

  for node in graph
    node.origSet = cloneSet node.set

  moveToIndependent = (node) ->
    independent.push node
    delete dependencies[name] for name in node.names

  for parent in graph when parent.set.numDependencies is 0
    moveToIndependent parent

  sorted = []
  while independent.length > 0
    finishedParent = independent.pop()
    sorted.push finishedParent
    for child in reversedDependencies[finishedParent.names[0]] or []
      removeDependency child.set, name for name in finishedParent.names
      moveToIndependent child if child.set.numDependencies is 0

  for node in sorted
    node.set = node.origSet

  for parent of dependencies
    throw new Error "Cyclic definitions between #{(name for name of dependencies).join ','}"
  sorted

reverseGraph = (nodes) ->
  reversed = {}
  for child in nodes
    for dependencyName of child.set.dependencies
      (reversed[dependencyName] ?= []).push child
  reversed

# Graph:
#   [{def: [pattern, def], set: [names that depend on this], names: [names in pattern]}]
# Lookup by name:
#   Map (name -> GraphElement)
constructDependencyGraph = (wheres) ->
  lookupByName = {}
  deps = dependencySet()
  # find all defined names
  graph = for [pattern, def], i in wheres
    def: [pattern, def]
    set: dependencySet()
    names: findNames pattern
    missing: dependencySet()

  lookupByName = lookupTableForGraph graph

  # then construct local graph
  for [pattern, def], i in wheres

    child = graph[i]
    crawlWhile def,
      (parent) ->
        not parent.type
      (node, token) ->
        definingScope = lookupIdentifier token, node
        parent = lookupByName[token]
        if parent
          addDependency child.set, name for name in parent.names unless child is parent
          addDependency deps, parent
        else if isReference(node) and !lookupIdentifier token, node
          addDependency child.missing, node.token
  [graph, lookupByName]

lookupTableForGraph = (graph) ->
  table = {}
  for where in graph
    {names} = where
    for name in names
      table[name] = where
  table

findNames = (pattern) ->
  names = []
  crawl pattern, (node) ->
    if node.label is 'name'
      names.push node.token
  names


dependencySet = ->
  numDependencies: 0
  dependencies: {}

addDependency = (set, parentName) ->
  return if set.dependencies[parentName]
  set.numDependencies += 1
  set.dependencies[parentName] = true

removeDependency = (set, parentName) ->
  return if !set.dependencies[parentName]
  set.numDependencies -= 1
  delete set.dependencies[parentName]

compileDef = ([name, def]) ->
  if !def?
    throw new Error 'missing definition in assignment'
  pm = patternMatch(name, compileImpl def)
  pm.precs.filter(({cache}) -> cache).map(({cache}) -> cache)
  .concat(pm.assigns).map(compileAssign).join '\n'

newVar = ->
  "i#{variableCounter++}"

repeat = (x, n) ->
  new Array(n + 1).join x

isSplat = (elem) ->
  elem.token and elem.token[...2] is '..'

stripSplatFromName = (token) ->
  if token[...2] is '..'
    token[2...]
  else
    token

patternMatchingRules = [
  (pattern) ->
    trigger: pattern.label is 'numerical'
    cond: (exp) -> ["#{exp}" + " == #{pattern.token}"]
  (pattern) ->
    trigger: pattern.label is 'const'
    cond: (exp) -> ["'#{pattern.token}' in #{exp}"]
  (pattern) ->
    trigger: pattern.label is 'name'
    assignTo: (exp) ->
      name = stripSplatFromName pattern.token
      if exp isnt identifier = validIdentifier name
        addToEnclosingScope name, pattern
        [[identifier, exp]]
      else
        []
  # (pattern) ->
  #   trigger: matchNode '&', pattern
  #   cache: true
  #   cond: (exp) -> ["'head' in #{exp}"]
  #   assignTo: (exp) ->
  #     [op, head, tail] = inside pattern
  #     recurse: [
  #       [head, "#{exp}.head"]
  #       [tail, "#{exp}.tail"]
  #     ]
  (pattern) ->
    # expect lists from here on
    if not Array.isArray pattern
      throw new Error "pattern match expected pattern but saw token #{pattern.token}"
    [constr, elems...] = inside pattern
    label = "'#{constr.token}'" if constr
    trigger: isMap pattern
    cache: true
    cacheMore: (exp) -> if elems.length > 1 then ["#{exp}[#{label}]"] else []
    cond: (exp) ->
      ["#{label} in #{exp}"]
    assignTo: (exp, value) ->
      value ?= "#{exp}[#{label}]"
      recurse: (for elem, i in elems
        [elem, "#{value}[#{i}]"])
  (pattern) ->
    elems = inside pattern
    hasSplat = no
    requiredElems = 0
    for elem in elems
      if isSplat elem
        hasSplat = yes
      else
        requiredElems++
    trigger: isList pattern
    cache: true
    cond: (exp) -> ["$sequenceSize(#{exp}) #{if hasSplat then '>=' else '=='} #{requiredElems}"]
    assignTo: (exp) ->
      recurse: (for elem, i in elems
        if isSplat elem
          [elem, "$sequenceSplat(#{i}, #{elems.length - i - 1}, #{exp})"]
        else
          [elem, "$sequenceAt(#{i}, #{exp})"])
  (pattern) ->
    elems = inside pattern
    trigger: isTuple pattern
    cache: true
    cond: (exp) ->
      ["#{exp}.length == #{elems.length}"]
    assignTo: (exp, value) ->
      value ?= exp
      recurse: (for elem, i in elems
        [elem, "#{value}[#{i}]"])
  (pattern) -> throw 'unrecognized pattern in pattern matching'

]

patternMatch = (pattern, def, defCache) ->
  for rule in patternMatchingRules
    appliedRule = rule pattern
    if appliedRule.trigger
      if not defCache and appliedRule.cache
        defCache = [markCache [newVar(), def]]
      if defCache
        def = defCache[0].cache[0]
      defCache ?= []
      moreCaches = (for c in ((appliedRule.cacheMore? def) ? [])
        [newVar(), c])
      cacheNames = moreCaches.map ([n]) -> n
      assignRule = appliedRule.assignTo? def, cacheNames...
      return if not assignRule
          precs: (appliedRule.cond def).map markCond
          assigns: []
        else if not assignRule.recurse
          precs: []
          assigns: assignRule
        else
          recursed = (patternMatch p, d for [p, d] in (assignRule.recurse ? []))
          conds = ((appliedRule.cond? def) ? []).map markCond
          precs: defCache.concat(conds, moreCaches.map(markCache), (recursed.map ({precs}) -> precs)...)
          assigns: [].concat (recursed.map ({assigns}) -> assigns)...

markCond = (x) -> cond: x
markCache = (x) -> cache: x

findDeclarables = (precs) ->
  precs.filter((p) -> p.cache).map(({cache}) -> cache[0])

macros =
  'if': (cond, zen, elz) ->
    """(function(){if (#{cond}) {
      return #{zen};
    } else {
      return #{elz};
    }}())"""
  'access': (field, obj) ->
    # TODO: use dot notation if method is valid field name
    "(#{obj})[#{field}]"
  'call': (method, obj, args...) ->
    "(#{macros.access method, obj}(#{args.join ', '}))"
  'new': (clazz, args...) ->
    "(new #{clazz}(#{args.join ', '}))"


trueMacros =
  'match': (hoistableWheres, onwhat, cases...) ->
    varNames = []
    if not onwhat
      throw new Error 'match `onwhat` missing'
    if cases.length % 2 != 0
      throw new Error 'match missing result for last pattern'
    exp = compileImpl onwhat
    compiledCases = (for [pattern, result], i in pairs cases
      control = if i is 0 then 'if' else ' else if'
      {precs, assigns} = patternMatch pattern, exp, mainCache
      vars = findDeclarables precs
      if vars.length >= 1
        mainCache = [precs[0]]
        varNames.push vars[1...]...
      else
        varNames.push vars...
      {conds, preassigns} = constructCond precs
      [hoistedWheres, furtherHoistable] = hoistWheres hoistableWheres, assigns
      """#{control} (#{conds}) {
          #{preassigns.concat(assigns).map(compileAssign).join '\n  '}
          #{hoistedWheres.map(compileDef).join '\n  '}
          return #{compileImpl result, furtherHoistable};
        }"""
      )
    mainCache ?= []
    mainCache = mainCache.map ({cache}) -> compileAssign cache
    varDecls = if varNames.length > 0 then ["var #{varNames.join ', '};"] else []
    content = mainCache.concat(varDecls, compiledCases.join '').join '\n'
    """(function(){
      #{content} else {throw new Error('match failed to match');}}())"""
  'require': (from, list) ->
    args = inside(list).map(compileName).map(toJsString).join ', '
    "$listize(window.requireModule(#{toJsString from.token}, [#{args}]))"
  'list': (items...) ->
    "$listize(#{compileList items})"

compileName = (node) ->
  validIdentifier node.token

hoistWheres = (hoistable, assigns) ->
  defined = addAllTo dependencySet(), (n for [n, _] in assigns)
  hoistedNames = dependencySet()
  hoisted = []
  notHoisted = []
  for where in hoistable
    {missing, names, def, set} = where
    stillMissingNames = addAllTo dependencySet(),
      (name for name in (setToArray missing) when not inSet defined, name)
    stillMissingDeps = removeAll (cloneSet set), setToArray hoistedNames
    if stillMissingNames.numDependencies == 0 and stillMissingDeps.numDependencies == 0
      hoisted.push def
      addAllTo hoistedNames, names
    else
      notHoisted.push
        def: def
        names: names
        missing: stillMissingNames
        set: stillMissingDeps
  [hoisted, notHoisted]

addAllTo = (set, array) ->
  for v in array
    addDependency set, v
  set

removeAll = (set, array) ->
  for v in array
    removeDependency set, v
  set

setToArray = (set) ->
  for n of set.dependencies
    n

cloneSet = (set) ->
  clone = dependencySet()
  addAllTo clone, setToArray set

inSet = (set, name) ->
  set.dependencies[name]

toJsString = (token) ->
  "'#{token}'"

compileAssign = ([to, from]) ->
  "var #{to} = #{from};"

constructCond = (precs) ->
  return conds: ['true'], preassigns: [] if precs.length is 0
  i = 0
  lastCond = false
  cases = []
  singleCase = []
  wrapUp = ->
    cases.push if singleCase.length is 1
      singleCase[0]
    else
      "(#{singleCase.join ', '})"
  for prec, i in precs
    if i is 0 and prec.cache
      continue
    if prec.cache and lastCond
      wrapUp()
      singleCase = []
    if prec.cache
      singleCase.push "(#{prec.cache[0]} = #{prec.cache[1]})"
    else
      lastCond = yes
      singleCase.push prec.cond
  preassigns = if lastCond
    wrapUp()
    []
  else
    singleCase.map ({cache}) -> cache
  conds: cases.join " && "
  preassigns: preassigns



expandBuiltings = (mapping, cb) ->
  for op, i in mapping.from
    macros[op] = cb mapping.to[i]

unaryFnMapping =
  from: '√ alert! not empty'.split ' '
  to: 'Math.sqrt window.log ! $empty'.split ' '

expandBuiltings unaryFnMapping, (to) ->
  (x) ->
    if x
      "#{to}(#{x})"
    else
      "function(__a){return #{to}(__a);}"

binaryFnMapping =
  from: []
  to: []

expandBuiltings binaryFnMapping, (to) ->
  (x, y) ->
    if x and y
      "#{to}(#{x}, #{y})"
    else if x
      "function(__b){return #{to}(#{a}, __b);}"
    else
      "function(__a, __b){return #{to}(__a, __b);}"

invertedBinaryFnMapping =
  from: '^'.split ' '
  to: 'Math.pow'.split ' '

expandBuiltings invertedBinaryFnMapping, (to) ->
  (x, y) ->
    if x and y
      "#{to}(#{y}, #{x})"
    else if x
      "function(__b){return #{to}(__b, #{a});}"
    else
      "function(__a, __b){return #{to}(__b, __a);}"

binaryOpMapping =
  from: '+ * = != and or'.split ' '
  to: '+ * == != && ||'.split ' '

expandBuiltings binaryOpMapping, (to) ->
  (x, y) ->
    if x and y
      "(#{x} #{to} #{y})"
    else if x
      "function(__b){return #{x} #{to} __b;}"
    else
      "function(__a, __b){return __a #{to} __b;}"

invertedBinaryOpMapping =
  from: '- / rem < > <= >='.split ' '
  to: '- / % < > <= >='.split ' '

expandBuiltings invertedBinaryOpMapping, (to) ->
  (x, y) ->
    if x and y
      "(#{y} #{to} #{x})"
    else if x
      "function(__b){return __b #{to} #{x};}"
    else
      "function(__a, __b){return __b #{to} __a;}"

topScopeDefines = ->
  ids = 'true false & show-list from-nullable'.split(' ')
    .concat unaryFnMapping.from,
      binaryOpMapping.from,
      binaryFnMapping.from,
      invertedBinaryOpMapping.from,
      invertedBinaryFnMapping.from,
      (key for own key of macros),
      (key for own key of trueMacros)
  scope = {}
  for id in ids
    scope[id] = true
  scope

# mycroft = (context, node, environment) ->
#   if node.label is 'numerical'
#     environment node.token
#   else if node.label is 'name'
#     environment node.token
#   else if node.type is 'function'
#     {params, type, doc, body, wheres} = fnDefinition node
#     mycroft (extendContext context, (paramTypes params, type)), body
#   else if Array.isArray node
#     [op, args...] = inside node
#     # for one arg for now
#     [s3, c] = mycroft context, op, environment
#     [s2, a] = mycroft (s3 context), args[0], environment
#     s1 = unify (s2 c), [a, fresh()]

# paramTypes = (params, fnType) ->
#   types = inside fnType
#   if types.length < params.length
#     throw new Error "Not enough types in type declaration"
#   context = {}
#   for param, i in params
#     context[param.token] = types[i].token
#   context



# unify = -> ???

# defaultEnvironment = (name) ->
#   switch name
#     when '+' then ['Int', 'Int']



library = """
var $listize = function (list) {
  if (list.length == 0) {
   return {length: 0};
  }
  return and_(list[0], $listize(list.slice(1)));
};

var and_ = function (x, xs) {
  if (typeof xs === "undefined" || xs === null) {
    throw new Error('Second argument to & must be a sequence');
  }
  if (typeof xs == 'string' || xs instanceof String) {
    if (xs == '' && !(typeof x == 'string' || x instanceof String)) {
      return [x];
    } else {
      return x + xs;
    }
  }
  if (xs.unshift) {
    return [x].concat(xs);
  }// cases for other sequences
  return {
    head: x,
    tail: xs
  };
};

var $sequenceSize = function (xs) {
  if (typeof xs === "undefined" || xs === null) {
    throw new Error('Pattern matching on size of undefined');
  }
  if (xs.length != null) {
    return xs.length;
  }
  return 1 + $sequenceSize(xs.tail);
};

var $sequenceAt = function (i, xs) {
  if (typeof xs === "undefined" || xs === null) {
    throw new Error('Pattern matching required sequence got undefined');
  }
  if (xs.length != null) {
    if (i >= xs.length) {
      throw new Error('Pattern matching required a list of size at least ' + (i + 1));
    }
    return xs[i];
  }
  if (i == 0) {
    return xs.head;
  }
  return $sequenceAt(i - 1, xs.tail);
};

var $sequenceSplat = function (from, leave, xs) {
  if (xs.slice) {
    return xs.slice(from, xs.length - leave);
  }
  return $listSlice(from, $sequenceSize(xs) - leave - from, xs);
};

// temporary, will be replaced by typed 0-argument function
var $empty = function (xs) {
  if (typeof xs === "undefined" || xs === null) {
    throw new Error('Empty needs a sequence');
  }
  if (typeof xs == 'string' || xs instanceof String) {
    return "";
  }
  if (xs.unshift) {
    return [];
  }
  if ('length' in xs) {
    return $listize([]);
  } // cases for other sequences
  return {};
};

var $listSlice = function (from, n, xs) {
  if (n == 0) {
    return $listize([]);
  }
  if (from == 0) {
    return and_(xs.head, $listSlice(from, n - 1, xs.tail));
  }
  return $listSlice(from - 1, n, xs.tail);
};

var show__list = function (x) {
  var t = [];
  while (x.length != 0) {
    t.push(x.head);
    x = x.tail;
  }
  return t;
};

var $curry = function (f) {
  var _curry = function(args) {
    return f.length == 1 ? f : function(){
      var params = args ? args.concat() : [];
      return params.push.apply(params, arguments) < f.length && arguments.length
        ? _curry.call(this, params)
        : f.apply(this, params);
    };
  };
  return _curry();
};

var from__nullable = function (jsValue) {
  if (typeof jsValue === "undefined" || jsValue === null) {
    return {';none': true};
  } else {
    return {':just': [jsValue]};
  }
};

;
"""

exports.compile = (source) ->
  library + compileDefinitions source

exports.compileModule = (source) ->
  """
  #{library}
  var exports = {};
  #{compileDefinitionsInModule source}
  exports"""

exports.compileExp = compiledBottom

exports.tokenize = tokenizedDefinitions

exports.tokenizeExp = tokenizedExp

exports.syntaxedExpHtml = syntaxedExp

exports.exportList = exportList

exports.library = library

exports.walk = walk