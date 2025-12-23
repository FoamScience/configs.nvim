local M = {}

local types = require('blink.cmp.types')

local unicode_items = {
    -- Logic & Quantifiers
    { label = "∀", insertText = "∀", kind = types.CompletionItemKind.Text, filterText = "forall for_all" },
    { label = "∃", insertText = "∃", kind = types.CompletionItemKind.Text, filterText = "exists" },
    { label = "¬", insertText = "¬", kind = types.CompletionItemKind.Text, filterText = "not neg negation" },
    { label = "∧", insertText = "∧", kind = types.CompletionItemKind.Text, filterText = "and land wedge" },
    { label = "∨", insertText = "∨", kind = types.CompletionItemKind.Text, filterText = "or lor vee" },
    { label = "⟹", insertText = "⟹", kind = types.CompletionItemKind.Text, filterText = "implies Longrightarrow" },
    { label = "⇒", insertText = "⇒", kind = types.CompletionItemKind.Text, filterText = "Rightarrow implies2" },
    { label = "⇔", insertText = "⇔", kind = types.CompletionItemKind.Text, filterText = "iff Leftrightarrow equivalent" },
    { label = "↔", insertText = "↔", kind = types.CompletionItemKind.Text, filterText = "leftrightarrow iff2" },

    -- Arrows
    { label = "→", insertText = "→", kind = types.CompletionItemKind.Text, filterText = "to rightarrow arrow fun" },
    { label = "←", insertText = "←", kind = types.CompletionItemKind.Text, filterText = "leftarrow from gets" },
    { label = "↦", insertText = "↦", kind = types.CompletionItemKind.Text, filterText = "mapsto" },

    -- Set Theory & Relations
    { label = "∈", insertText = "∈", kind = types.CompletionItemKind.Text, filterText = "in mem member element" },
    { label = "∉", insertText = "∉", kind = types.CompletionItemKind.Text, filterText = "notin notmem notelement" },
    { label = "⊆", insertText = "⊆", kind = types.CompletionItemKind.Text, filterText = "subseteq subset" },
    { label = "⊂", insertText = "⊂", kind = types.CompletionItemKind.Text, filterText = "subset propersubset ssubset" },
    { label = "⊇", insertText = "⊇", kind = types.CompletionItemKind.Text, filterText = "supseteq superset" },
    { label = "∪", insertText = "∪", kind = types.CompletionItemKind.Text, filterText = "cup union" },
    { label = "∩", insertText = "∩", kind = types.CompletionItemKind.Text, filterText = "cap intersection inter" },
    { label = "∅", insertText = "∅", kind = types.CompletionItemKind.Text, filterText = "emptyset empty" },

    -- Proof & Turnstiles
    { label = "⊨", insertText = "⊨", kind = types.CompletionItemKind.Text, filterText = "entails models vDash" },
    { label = "⊢", insertText = "⊢", kind = types.CompletionItemKind.Text, filterText = "provable vdash turnstile" },
    { label = "⊣", insertText = "⊣", kind = types.CompletionItemKind.Text, filterText = "dashv" },

    -- Comparison & Equality
    { label = "≤", insertText = "≤", kind = types.CompletionItemKind.Text, filterText = "le leq lessthanorequal" },
    { label = "≥", insertText = "≥", kind = types.CompletionItemKind.Text, filterText = "ge geq greaterthanorequal" },
    { label = "≠", insertText = "≠", kind = types.CompletionItemKind.Text, filterText = "ne neq notequal" },
    { label = "≈", insertText = "≈", kind = types.CompletionItemKind.Text, filterText = "approx approximate" },
    { label = "≡", insertText = "≡", kind = types.CompletionItemKind.Text, filterText = "equiv identical" },
    { label = "≺", insertText = "≺", kind = types.CompletionItemKind.Text, filterText = "prec precedes pareto dominates" },
    { label = "≻", insertText = "≻", kind = types.CompletionItemKind.Text, filterText = "succ succeeds" },

    -- Number Sets
    { label = "ℕ", insertText = "ℕ", kind = types.CompletionItemKind.Text, filterText = "Nat naturals N" },
    { label = "ℤ", insertText = "ℤ", kind = types.CompletionItemKind.Text, filterText = "Int integers Z" },
    { label = "ℚ", insertText = "ℚ", kind = types.CompletionItemKind.Text, filterText = "Rat rationals Q" },
    { label = "ℝ", insertText = "ℝ", kind = types.CompletionItemKind.Text, filterText = "Real reals R" },
    { label = "ℂ", insertText = "ℂ", kind = types.CompletionItemKind.Text, filterText = "Complex C" },

    -- Greek Letters (lowercase)
    { label = "α", insertText = "α", kind = types.CompletionItemKind.Text, filterText = "alpha" },
    { label = "β", insertText = "β", kind = types.CompletionItemKind.Text, filterText = "beta" },
    { label = "γ", insertText = "γ", kind = types.CompletionItemKind.Text, filterText = "gamma" },
    { label = "δ", insertText = "δ", kind = types.CompletionItemKind.Text, filterText = "delta" },
    { label = "ε", insertText = "ε", kind = types.CompletionItemKind.Text, filterText = "epsilon eps" },
    { label = "ζ", insertText = "ζ", kind = types.CompletionItemKind.Text, filterText = "zeta" },
    { label = "η", insertText = "η", kind = types.CompletionItemKind.Text, filterText = "eta" },
    { label = "θ", insertText = "θ", kind = types.CompletionItemKind.Text, filterText = "theta" },
    { label = "ι", insertText = "ι", kind = types.CompletionItemKind.Text, filterText = "iota" },
    { label = "κ", insertText = "κ", kind = types.CompletionItemKind.Text, filterText = "kappa" },
    { label = "λ", insertText = "λ", kind = types.CompletionItemKind.Text, filterText = "lambda lam fun" },
    { label = "μ", insertText = "μ", kind = types.CompletionItemKind.Text, filterText = "mu" },
    { label = "ν", insertText = "ν", kind = types.CompletionItemKind.Text, filterText = "nu" },
    { label = "ξ", insertText = "ξ", kind = types.CompletionItemKind.Text, filterText = "xi" },
    { label = "π", insertText = "π", kind = types.CompletionItemKind.Text, filterText = "pi" },
    { label = "ρ", insertText = "ρ", kind = types.CompletionItemKind.Text, filterText = "rho" },
    { label = "σ", insertText = "σ", kind = types.CompletionItemKind.Text, filterText = "sigma" },
    { label = "τ", insertText = "τ", kind = types.CompletionItemKind.Text, filterText = "tau" },
    { label = "υ", insertText = "υ", kind = types.CompletionItemKind.Text, filterText = "upsilon" },
    { label = "φ", insertText = "φ", kind = types.CompletionItemKind.Text, filterText = "phi varphi" },
    { label = "χ", insertText = "χ", kind = types.CompletionItemKind.Text, filterText = "chi" },
    { label = "ψ", insertText = "ψ", kind = types.CompletionItemKind.Text, filterText = "psi" },
    { label = "ω", insertText = "ω", kind = types.CompletionItemKind.Text, filterText = "omega" },

    -- Greek Letters (uppercase)
    { label = "Γ", insertText = "Γ", kind = types.CompletionItemKind.Text, filterText = "Gamma" },
    { label = "Δ", insertText = "Δ", kind = types.CompletionItemKind.Text, filterText = "Delta" },
    { label = "Θ", insertText = "Θ", kind = types.CompletionItemKind.Text, filterText = "Theta" },
    { label = "Λ", insertText = "Λ", kind = types.CompletionItemKind.Text, filterText = "Lambda" },
    { label = "Ξ", insertText = "Ξ", kind = types.CompletionItemKind.Text, filterText = "Xi" },
    { label = "Π", insertText = "Π", kind = types.CompletionItemKind.Text, filterText = "Pi" },
    { label = "Σ", insertText = "Σ", kind = types.CompletionItemKind.Text, filterText = "Sigma" },
    { label = "Υ", insertText = "Υ", kind = types.CompletionItemKind.Text, filterText = "Upsilon" },
    { label = "Φ", insertText = "Φ", kind = types.CompletionItemKind.Text, filterText = "Phi" },
    { label = "Ψ", insertText = "Ψ", kind = types.CompletionItemKind.Text, filterText = "Psi" },
    { label = "Ω", insertText = "Ω", kind = types.CompletionItemKind.Text, filterText = "Omega" },

    -- Math Operations
    { label = "∑", insertText = "∑", kind = types.CompletionItemKind.Text, filterText = "sum Sum" },
    { label = "∏", insertText = "∏", kind = types.CompletionItemKind.Text, filterText = "prod Prod product" },
    { label = "∫", insertText = "∫", kind = types.CompletionItemKind.Text, filterText = "int integral" },
    { label = "∂", insertText = "∂", kind = types.CompletionItemKind.Text, filterText = "partial del" },
    { label = "∇", insertText = "∇", kind = types.CompletionItemKind.Text, filterText = "nabla grad gradient" },
    { label = "√", insertText = "√", kind = types.CompletionItemKind.Text, filterText = "sqrt root" },
    { label = "∞", insertText = "∞", kind = types.CompletionItemKind.Text, filterText = "infty infinity inf" },
    { label = "·", insertText = "·", kind = types.CompletionItemKind.Text, filterText = "cdot dot mul" },
    { label = "×", insertText = "×", kind = types.CompletionItemKind.Text, filterText = "times cross prod" },
    { label = "÷", insertText = "÷", kind = types.CompletionItemKind.Text, filterText = "div divide" },
    { label = "±", insertText = "±", kind = types.CompletionItemKind.Text, filterText = "pm plusminus" },
    { label = "∓", insertText = "∓", kind = types.CompletionItemKind.Text, filterText = "mp minusplus" },

    -- Subscripts & Superscripts
    { label = "₀", insertText = "₀", kind = types.CompletionItemKind.Text, filterText = "sub0 _0" },
    { label = "₁", insertText = "₁", kind = types.CompletionItemKind.Text, filterText = "sub1 _1" },
    { label = "₂", insertText = "₂", kind = types.CompletionItemKind.Text, filterText = "sub2 _2" },
    { label = "₃", insertText = "₃", kind = types.CompletionItemKind.Text, filterText = "sub3 _3" },
    { label = "ₙ", insertText = "ₙ", kind = types.CompletionItemKind.Text, filterText = "subn _n" },
    { label = "ᵢ", insertText = "ᵢ", kind = types.CompletionItemKind.Text, filterText = "subi _i" },
    { label = "ⱼ", insertText = "ⱼ", kind = types.CompletionItemKind.Text, filterText = "subj _j" },
    { label = "⁰", insertText = "⁰", kind = types.CompletionItemKind.Text, filterText = "sup0 ^0" },
    { label = "¹", insertText = "¹", kind = types.CompletionItemKind.Text, filterText = "sup1 ^1" },
    { label = "²", insertText = "²", kind = types.CompletionItemKind.Text, filterText = "sup2 ^2 squared" },
    { label = "³", insertText = "³", kind = types.CompletionItemKind.Text, filterText = "sup3 ^3 cubed" },
    { label = "ⁿ", insertText = "ⁿ", kind = types.CompletionItemKind.Text, filterText = "supn ^n" },
    { label = "⁻¹", insertText = "⁻¹", kind = types.CompletionItemKind.Text, filterText = "inv inverse ^-1" },

    -- Special Symbols
    { label = "ℓ", insertText = "ℓ", kind = types.CompletionItemKind.Text, filterText = "ell script_l lengthscale" },
    { label = "ℏ", insertText = "ℏ", kind = types.CompletionItemKind.Text, filterText = "hbar" },
    { label = "★", insertText = "★", kind = types.CompletionItemKind.Text, filterText = "star" },
    { label = "†", insertText = "†", kind = types.CompletionItemKind.Text, filterText = "dagger" },
    { label = "‡", insertText = "‡", kind = types.CompletionItemKind.Text, filterText = "ddagger" },
    { label = "∘", insertText = "∘", kind = types.CompletionItemKind.Text, filterText = "circ compose" },
    { label = "⊕", insertText = "⊕", kind = types.CompletionItemKind.Text, filterText = "oplus directsum" },
    { label = "⊗", insertText = "⊗", kind = types.CompletionItemKind.Text, filterText = "otimes tensor" },
    { label = "⊥", insertText = "⊥", kind = types.CompletionItemKind.Text, filterText = "bot perp false" },
    { label = "⊤", insertText = "⊤", kind = types.CompletionItemKind.Text, filterText = "top true" },

    -- Brackets & Delimiters
    { label = "⟨", insertText = "⟨", kind = types.CompletionItemKind.Text, filterText = "langle lang <<" },
    { label = "⟩", insertText = "⟩", kind = types.CompletionItemKind.Text, filterText = "rangle rang >>" },
    { label = "⟦", insertText = "⟦", kind = types.CompletionItemKind.Text, filterText = "llbracket" },
    { label = "⟧", insertText = "⟧", kind = types.CompletionItemKind.Text, filterText = "rrbracket" },
    { label = "⌊", insertText = "⌊", kind = types.CompletionItemKind.Text, filterText = "lfloor floor" },
    { label = "⌋", insertText = "⌋", kind = types.CompletionItemKind.Text, filterText = "rfloor" },
    { label = "⌈", insertText = "⌈", kind = types.CompletionItemKind.Text, filterText = "lceil ceil" },
    { label = "⌉", insertText = "⌉", kind = types.CompletionItemKind.Text, filterText = "rceil" },
}

function M.new(opts)
    local self = setmetatable({}, { __index = M })
    self.opts = opts
    self.opts.name = "unicode"
    self.opts.items = unicode_items
    return self
end

function M:enabled() return vim.bo.filetype == "lean" end

function M:get_trigger_characters() return {} end

function M:get_completions(ctx, callback)
    -- Don't trigger on dot
    local line = ctx.line
    local col = ctx.cursor[2]
    if col > 0 and line:sub(col, col) == "." then
        callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
        return function() end
    end

    callback({
        items = unicode_items,
        is_incomplete_backward = true,
        is_incomplete_forward = true,
    })
    return function() end
end

return M
