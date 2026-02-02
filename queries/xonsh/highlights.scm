; Xonsh-specific highlighting queries
; These extend Python highlights with xonsh syntax

; ===========================================================================
; Bare Subprocess (highest priority - detected by scanner heuristics)
; ===========================================================================

; Bare subprocess detected by scanner (e.g., "ls -la", "cd $HOME")
(bare_subprocess
  body: (subprocess_body
    (subprocess_command
      (subprocess_argument
        (subprocess_word) @function.call))))

; Highlight the first word of a bare subprocess as a command
(bare_subprocess
  body: (subprocess_body
    (subprocess_command
      . (subprocess_argument
          (subprocess_word) @function.builtin))))

; ===========================================================================
; Environment Variables (high priority)
; ===========================================================================

((env_variable
  "$" @punctuation.special
  (identifier) @variable.builtin) @_env
  (#set! "priority" 110))

((env_variable_braced
  "${" @punctuation.special
  "}" @punctuation.special) @_env_braced
  (#set! "priority" 110))

; ===========================================================================
; Environment Variable Assignment and Deletion
; ===========================================================================

(env_assignment
  "=" @operator)

(env_deletion
  "del" @keyword)

; ===========================================================================
; Subprocess Operators (high priority to override punctuation.bracket)
; ===========================================================================

; Captured subprocess $()
((captured_subprocess
  "$(" @punctuation.special
  ")" @punctuation.special) @_cap_sub
  (#set! "priority" 110))

; Captured subprocess object !()
((captured_subprocess_object
  "!(" @punctuation.special
  ")" @punctuation.special) @_cap_obj
  (#set! "priority" 110))

; Uncaptured subprocess $[]
((uncaptured_subprocess
  "$[" @punctuation.special
  "]" @punctuation.special) @_uncap_sub
  (#set! "priority" 110))

; Uncaptured subprocess object ![]
((uncaptured_subprocess_object
  "![" @punctuation.special
  "]" @punctuation.special) @_uncap_obj
  (#set! "priority" 110))

; ===========================================================================
; Python Evaluation in Subprocess
; ===========================================================================

; @() - Python evaluation
((python_evaluation
  "@(" @punctuation.special
  ")" @punctuation.special) @_py_eval
  (#set! "priority" 110))

; @$() - Tokenized substitution
((tokenized_substitution
  "@$(" @punctuation.special
  ")" @punctuation.special) @_tok_sub
  (#set! "priority" 110))

; ===========================================================================
; Special @ Object
; ===========================================================================

(at_object
  "@" @punctuation.special
  "." @punctuation.delimiter
  attribute: (identifier) @property)

; ===========================================================================
; Glob Patterns
; ===========================================================================

; Regex glob `pattern`
((regex_glob
  "`" @punctuation.special
  (regex_glob_content) @string.regexp
  "`" @punctuation.special) @_regex_glob
  (#set! "priority" 110))

; Standard glob g`pattern`
((glob_pattern
  "g`" @punctuation.special
  (glob_pattern_content) @string.special
  "`" @punctuation.special) @_glob
  (#set! "priority" 110))

; Formatted glob f`pattern`
((formatted_glob
  "f`" @punctuation.special
  (formatted_glob_content) @string.special
  "`" @punctuation.special) @_fglob
  (#set! "priority" 110))

; ===========================================================================
; Path Literals
; ===========================================================================

(path_string
  prefix: (path_prefix) @string.special.symbol)

; ===========================================================================
; Subprocess Modifiers (@json, @yaml, etc.)
; ===========================================================================

(subprocess_modifier) @attribute

; ===========================================================================
; Scoped Environment Variable Command ($VAR=value cmd)
; ===========================================================================

(env_scoped_command
  env: (env_prefix
    (env_variable
      (identifier) @variable.builtin)
    "=" @operator))

; ===========================================================================
; Glob Path (gp`pattern`)
; ===========================================================================

((glob_path
  "gp`" @punctuation.special
  (glob_path_content) @string.special
  "`" @punctuation.special) @_glob_path
  (#set! "priority" 110))

; Regex path glob (rp`pattern`)
((regex_path_glob
  "rp`" @punctuation.special
  (regex_path_content) @string.regexp
  "`" @punctuation.special) @_rp_glob
  (#set! "priority" 110))

; Custom function glob @func`pattern`
((custom_function_glob
  "@" @punctuation.special
  function: (identifier) @function.call
  "`" @punctuation.special
  pattern: (custom_glob_content) @string.special
  "`" @punctuation.special) @_custom_glob
  (#set! "priority" 110))

; ===========================================================================
; Brace Expansion
; ===========================================================================

; Brace expansion list {a,b,c}
(brace_expansion
  "{" @punctuation.special
  "}" @punctuation.special)

(brace_expansion
  "," @punctuation.delimiter)

; Range expansion {1..5} - matched as atomic token
(brace_range) @string.special

; List items
(brace_item) @string.special

; Brace literal {123} - single item, no expansion
(brace_literal) @string.special

; ===========================================================================
; Subprocess Body - Command and Arguments
; ===========================================================================

; First word of subprocess command is the command name
(subprocess_command
  . (subprocess_argument
      (subprocess_word) @function.call))

; Subsequent subprocess words are arguments
(subprocess_argument
  (subprocess_word) @string.special)

; Flags in subprocess arguments (words starting with -)
((subprocess_word) @variable.parameter
  (#match? @variable.parameter "^-"))

; ===========================================================================
; Subprocess Pipeline
; ===========================================================================

; Command after pipe
(subprocess_pipeline
  (subprocess_command
    . (subprocess_argument
        (subprocess_word) @function.call)))

; ===========================================================================
; Subprocess Logical (&&, ||, and, or)
; ===========================================================================

; Command after logical operator
(subprocess_logical
  (subprocess_command
    . (subprocess_argument
        (subprocess_word) @function.call)))

; ===========================================================================
; Subprocess Redirections
; ===========================================================================

; Redirect target (filename, variable, etc.)
(redirect_target
  (subprocess_word) @string.special.path)

(redirect_target
  (env_variable) @variable.builtin)

; ===========================================================================
; Pipes and Operators
; ===========================================================================

(pipe_operator) @operator

(redirect_operator) @keyword.operator

(stream_merge_operator) @keyword.operator

(logical_operator) @keyword.operator

; ===========================================================================
; Background Execution
; ===========================================================================

; Note: background_command uses an external token (_background_amp) which
; is anonymous and cannot be queried directly. The command itself is
; highlighted via xonsh_expression.

; ===========================================================================
; Xontrib Statements
; ===========================================================================

; xontrib keyword
(xontrib_statement
  "xontrib" @keyword)

; load keyword
(xontrib_statement
  "load" @keyword)

; xontrib names (the packages being loaded)
(xontrib_name) @module

; ===========================================================================
; Macro Calls
; ===========================================================================

; Macro call: func!(args) - name highlighted same as function definition
; Note: "!(" is a single token, cannot highlight ! separately
(macro_call
  name: (identifier) @function
  "!(" @punctuation.special
  ")" @punctuation.special)

(macro_call
  argument: (macro_argument) @string.special)

; ===========================================================================
; Subprocess Macro (cmd! args)
; ===========================================================================

; The subprocess macro argument is raw text
(subprocess_macro
  argument: (subprocess_macro_argument) @string.special)

; ===========================================================================
; Block Macro (with! Context():)
; ===========================================================================

; Block macro uses with! syntax (single token)
(block_macro_statement
  "with!" @keyword)

; ===========================================================================
; Help Expressions
; ===========================================================================

; Single ? for help
(help_expression
  "?" @punctuation.special)

; Double ?? for super help (source)
(super_help_expression
  "??" @punctuation.special)

; ===========================================================================
; Python Highlights
; ===========================================================================

; Comments
(comment) @comment

; Strings
(string) @string
(string_content) @string

; Escape sequences
(escape_sequence) @string.escape

; Numbers
(integer) @number
(float) @number.float

; Booleans
((identifier) @boolean
  (#any-of? @boolean "True" "False"))

; None
((identifier) @constant.builtin
  (#eq? @constant.builtin "None"))

; Self
((identifier) @variable.builtin
  (#eq? @variable.builtin "self"))

; cls
((identifier) @variable.builtin
  (#eq? @variable.builtin "cls"))

; Identifiers
(identifier) @variable

; Function definitions
(function_definition
  name: (identifier) @function)

; Function parameters
(parameters
  (identifier) @variable.parameter)

; Function calls
(call
  function: (identifier) @function.call)

(call
  function: (attribute
    attribute: (identifier) @function.method.call))

; Class definitions
(class_definition
  name: (identifier) @type)

; Decorators
(decorator
  "@" @attribute
  (identifier) @attribute)

; Attributes
(attribute
  attribute: (identifier) @property)

; Imports
(import_statement
  "import" @keyword.import)

(import_from_statement
  "from" @keyword.import
  "import" @keyword.import)

(aliased_import
  "as" @keyword.import)

(dotted_name
  (identifier) @module)

; Keywords
[
  "and"
  "as"
  "assert"
  "async"
  "await"
  "break"
  "class"
  "continue"
  "def"
  "del"
  "elif"
  "else"
  "except"
  "finally"
  "for"
  "from"
  "global"
  "if"
  "import"
  "in"
  "is"
  "lambda"
  "nonlocal"
  "not"
  "or"
  "pass"
  "raise"
  "return"
  "try"
  "while"
  "with"
  "yield"
  "match"
  "case"
  "type"
] @keyword

; Exception handling
(raise_statement "raise" @keyword.exception)
(try_statement "try" @keyword.exception)
(except_clause "except" @keyword.exception)
(finally_clause "finally" @keyword.exception)

; Operators
[
  "+"
  "-"
  "*"
  "**"
  "/"
  "//"
  "%"
  "@"
  "|"
  "&"
  "^"
  "~"
  "<<"
  ">>"
  "<"
  ">"
  "<="
  ">="
  "=="
  "!="
  ":="
] @operator

; Assignment operators
[
  "="
  "+="
  "-="
  "*="
  "/="
  "//="
  "%="
  "**="
  "&="
  "|="
  "^="
  ">>="
  "<<="
  "@="
] @operator

; Punctuation (lower priority than xonsh-specific)
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

[
  ","
  "."
  ":"
  ";"
  "->"
] @punctuation.delimiter

; Builtins
((identifier) @function.builtin
  (#any-of? @function.builtin
    "abs" "all" "any" "ascii" "bin" "bool" "breakpoint" "bytearray"
    "bytes" "callable" "chr" "classmethod" "compile" "complex"
    "delattr" "dict" "dir" "divmod" "enumerate" "eval" "exec"
    "filter" "float" "format" "frozenset" "getattr" "globals"
    "hasattr" "hash" "help" "hex" "id" "input" "int" "isinstance"
    "issubclass" "iter" "len" "list" "locals" "map" "max"
    "memoryview" "min" "next" "object" "oct" "open" "ord" "pow"
    "print" "property" "range" "repr" "reversed" "round" "set"
    "setattr" "slice" "sorted" "staticmethod" "str" "sum" "super"
    "tuple" "type" "vars" "zip" "__import__"))

; Xonsh builtins
((identifier) @function.builtin
  (#any-of? @function.builtin
    "aliases" "xontrib" "source" "xonfig" "xonsh"
    "cd" "pushd" "popd" "dirs"))

; Error nodes
(ERROR) @error
