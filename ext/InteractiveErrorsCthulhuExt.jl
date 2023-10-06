module InteractiveErrorsCthulhuExt

import Cthulhu
import InteractiveErrors

InteractiveErrors.has_cthulhu() = true

InteractiveErrors.ascend(mi::Core.MethodInstance) = Cthulhu.ascend(mi)

InteractiveErrors.descend(mi::Core.MethodInstance) = Cthulhu.descend(mi)

end
