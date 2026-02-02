; Xonsh locals queries for scope tracking
; Extends Python's scope rules

; ===========================================================================
; Scopes
; ===========================================================================

; Module scope
(module) @local.scope

; Function scope
(function_definition) @local.scope

; Class scope
(class_definition) @local.scope

; Lambda scope
(lambda) @local.scope

; Comprehension scopes
(list_comprehension) @local.scope
(dictionary_comprehension) @local.scope
(set_comprehension) @local.scope
(generator_expression) @local.scope

; ===========================================================================
; Definitions
; ===========================================================================

; Function definitions
(function_definition
  name: (identifier) @local.definition.function)

; Class definitions
(class_definition
  name: (identifier) @local.definition.type)

; Parameters
(parameters
  (identifier) @local.definition.parameter)

(default_parameter
  name: (identifier) @local.definition.parameter)

(typed_parameter
  (identifier) @local.definition.parameter)

(typed_default_parameter
  name: (identifier) @local.definition.parameter)

(list_splat_pattern
  (identifier) @local.definition.parameter)

(dictionary_splat_pattern
  (identifier) @local.definition.parameter)

; Keyword-only parameter separator doesn't define anything
; but parameters after it are still definitions

; Assignment targets
(assignment
  left: (identifier) @local.definition.var)

(assignment
  left: (pattern_list
    (identifier) @local.definition.var))

(assignment
  left: (tuple_pattern
    (identifier) @local.definition.var))

; Augmented assignment
(augmented_assignment
  left: (identifier) @local.definition.var)

; For loop variables
(for_statement
  left: (identifier) @local.definition.var)

(for_statement
  left: (pattern_list
    (identifier) @local.definition.var))

(for_statement
  left: (tuple_pattern
    (identifier) @local.definition.var))

; Comprehension iterators
(for_in_clause
  left: (identifier) @local.definition.var)

(for_in_clause
  left: (pattern_list
    (identifier) @local.definition.var))

(for_in_clause
  left: (tuple_pattern
    (identifier) @local.definition.var))

; With statement
(with_clause
  (with_item
    value: (as_pattern
      alias: (as_pattern_target
        (identifier) @local.definition.var))))

; Exception handlers
(except_clause
  (as_pattern
    alias: (as_pattern_target
      (identifier) @local.definition.var)))

; Import statements
(import_statement
  name: (dotted_name
    (identifier) @local.definition.import))

(import_statement
  name: (aliased_import
    alias: (identifier) @local.definition.import))

(import_from_statement
  name: (dotted_name
    (identifier) @local.definition.import))

(import_from_statement
  name: (aliased_import
    alias: (identifier) @local.definition.import))

; Global and nonlocal declarations
(global_statement
  (identifier) @local.definition.var)

(nonlocal_statement
  (identifier) @local.definition.var)

; Named expression (walrus operator)
(named_expression
  name: (identifier) @local.definition.var)

; Match statement patterns
(as_pattern
  alias: (as_pattern_target
    (identifier) @local.definition.var))

; ===========================================================================
; References
; ===========================================================================

; All identifiers are potential references
(identifier) @local.reference

; ===========================================================================
; Xonsh-specific Scopes
; ===========================================================================

; Subprocess bodies have their own pseudo-scope for command names
(subprocess_body) @local.scope

; Environment variable access is a special kind of reference
(env_variable
  (identifier) @local.reference)

; Python evaluation inside subprocess brings Python scope
(python_evaluation) @local.scope
