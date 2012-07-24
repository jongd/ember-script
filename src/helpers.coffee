{concatMap, difference, foldl, nub} = require './functional-helpers'
CS = require './nodes'

# these are the identifiers that need to be declared when the given value is
# being used as the target of an assignment
@beingDeclared = beingDeclared = (assignment) -> switch
  when not assignment? then []
  when assignment.instanceof CS.Identifier then [assignment.data]
  when assignment.instanceof CS.AssignOp then beingDeclared assignment.assignee
  when assignment.instanceof CS.ArrayInitialiser then concatMap assignment.members, beingDeclared
  when assignment.instanceof CS.ObjectInitialiser then concatMap assignment.vals(), beingDeclared
  else throw new Error "beingDeclared: Non-exhaustive patterns in case: #{assignment.className}"

@declarationsFor = (node, inScope) ->
  vars = envEnrichments node, inScope
  foldl (new CS.Undefined).g(), vars, (expr, v) ->
    (new CS.AssignOp (new CS.Identifier v).g(), expr).g()

# TODO: name change; this tests when a node is *being used as a value*
usedAsExpression_ = (node, parent, grandparent, otherAncestors...) -> switch
  when !parent? then yes
  when parent.instanceof CS.Program, CS.Class then no
  when parent.instanceof CS.SeqOp then this is parent.right
  when (parent.instanceof CS.Block) and
  (parent.statements.indexOf this) isnt parent.statements.length - 1
    no
  when (parent.instanceof CS.Function, CS.BoundFunction) and
  parent.body is this and
  (grandparent?.instanceof CS.ClassProtoAssignOp) and
  (grandparent.assignee.instanceof CS.String) and
  grandparent.assignee.data is 'constructor'
    no
  else yes

@usedAsExpression = (node, ancestors) ->
  usedAsExpression_.apply node, [node, ancestors...]

# environment enrichments that occur when this node is evaluated
envEnrichments_ = (inScope = []) ->
  possibilities = switch
    when @instanceof CS.AssignOp then nub beingDeclared @assignee
    when @instanceof CS.Class
      nub concat [
        beingDeclared @nameAssignment
        beingDeclared @parent
        if name? then [name] else []
      ]
    when @instanceof CS.ForIn, CS.ForOf
      nub concat [
        concatMap @childNodes, (child) =>
          if child in @listMembers
          then concatMap @[child], (m) -> envEnrichments m, inScope
          else envEnrichments @[child], inScope
        beingDeclared @keyAssignee
        beingDeclared @valAssignee
      ]
    else
      nub concatMap @childNodes, (child) =>
        if child in @listMembers
        then concatMap @[child], (m) -> envEnrichments m, inScope
        else envEnrichments @[child], inScope
  difference possibilities, inScope

@envEnrichments = envEnrichments = (node, args...) ->
  if node? then envEnrichments_.apply node, args else []
