module InteractiveErrorsOhMyREPLExt

import OhMyREPL
import InteractiveErrors
import PrecompileTools

InteractiveErrors.has_ohmyrepl() = true

function InteractiveErrors.highlight(source::String)
    O = OhMyREPL
    # OhMyREPL 0.6+ delegates to the REPL's native highlighter and drops its tokenizer.
    if isdefined(O, :JuliaSyntaxHighlighting)
        highlighted = O.JuliaSyntaxHighlighting.highlight(source)
        return sprint(print, highlighted; context = :color => true)
    end
    tokens = collect(O.tokenize(source))
    crayons = fill(O.Crayon(), length(tokens))
    O.Passes.SyntaxHighlighter.SYNTAX_HIGHLIGHTER_SETTINGS(crayons, tokens, 0, source)
    io = IOBuffer()
    for (token, crayon) in zip(tokens, crayons)
        print(io, crayon)
        print(io, O.untokenize(token, source))
        print(io, O.Crayon(reset = true))
    end
    return String(take!(io))
end

PrecompileTools.@compile_workload begin
    InteractiveErrors.highlight(
        read(joinpath(@__DIR__, "..", "src", "InteractiveErrors.jl"), String),
    )
end

end
