module InteractiveErrorsJuliaFormatterExt

import JuliaFormatter
import InteractiveErrors
import PrecompileTools

InteractiveErrors.has_juliaformatter() = true

function InteractiveErrors.format_julia_source(source::String)
    try
        return JuliaFormatter.format_text(source)
    catch err
        @debug "failed to format source" err source
        return source
    end
end

PrecompileTools.@compile_workload begin
    InteractiveErrors.format_julia_source(
        read(joinpath(@__DIR__, "..", "src", "InteractiveErrors.jl"), String),
    )
end

end
