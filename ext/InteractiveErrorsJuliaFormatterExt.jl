module InteractiveErrorsJuliaFormatterExt

import JuliaFormatter
import InteractiveErrors

InteractiveErrors.has_juliaformatter() = true

function InteractiveErrors.format_julia_source(source::String)
    try
        return JuliaFormatter.format_text(source)
    catch err
        @debug "failed to format source" err source
        return source
    end
end

end
