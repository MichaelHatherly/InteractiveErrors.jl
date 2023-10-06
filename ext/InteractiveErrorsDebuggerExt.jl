module InteractiveErrorsDebuggerExt

import Debugger
import InteractiveErrors

InteractiveErrors.has_debugger() = true

InteractiveErrors.breakpoint(file::AbstractString, line::Integer) = Debugger.breakpoint(file, line)

end
