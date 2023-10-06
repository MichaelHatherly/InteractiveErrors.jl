module InteractiveErrorsJETExt

import JET
import InteractiveErrors

InteractiveErrors.has_jet() = true

function InteractiveErrors.report_call(mi::Core.MethodInstance)
    func = Base.tuple_type_head(mi.specTypes).instance
    sig = Base.tuple_type_tail(mi.specTypes)
    result = JET.report_call(func, sig)
    @info "Press return to continue."
    readline()
    return result
end

end
