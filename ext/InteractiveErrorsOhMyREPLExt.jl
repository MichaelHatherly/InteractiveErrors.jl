module InteractiveErrorsOhMyREPLExt

import OhMyREPL
import InteractiveErrors

InteractiveErrors.has_ohmyrepl() = true

function InteractiveErrors.highlight(source::String)
    O = OhMyREPL
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

end
