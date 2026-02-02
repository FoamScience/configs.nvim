; Xonsh injection queries
; These define where other languages should be injected

; Regex glob patterns could use regex highlighting
(regex_glob
  (regex_glob_content) @injection.content
  (#set! injection.language "regex"))

; Python docstrings (optional rst/markdown injection)
(expression_statement
  (string
    (string_content) @injection.content)
  (#lua-match? @injection.content "^%s*[A-Z]")
  (#set! injection.language "rst")
  (#set! injection.include-children))

; Format strings could have Python expressions
; (handled natively by the grammar)

; Shell-like content in subprocess bodies
; Note: This is informational; the grammar handles subprocess parsing natively
; (subprocess_body) @injection.content
; (#set! injection.language "bash")
