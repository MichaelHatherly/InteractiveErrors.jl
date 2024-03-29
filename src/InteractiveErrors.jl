module InteractiveErrors

using FoldingTrees

using REPL, REPL.TerminalMenus, InteractiveUtils, IterTools

import PackageExtensionCompat, PrecompileTools

export toggle, current_theme, set_theme!, reset_theme!, adjust_theme!


#
# Themes.
#

const DEFAULT_THEME = (
    function_name = (bold = true,),
    directory = (color = :light_black,),
    filename = (color = :magenta, bold = true),
    line_number = (color = :green, bold = true),
    user_stack = (color = :green, bold = true),
    system_stack = (color = :red, bold = true),
    stdlib_module = (color = :yellow,),
    base_module = (color = :blue,),
    core_module = (color = :light_black,),
    package_module = (color = :cyan, bold = true),
    unknown_module = (color = :red,),
    inlined_frames = (color = :light_black,),
    toplevel_frames = (color = :light_black,),
    repeated_frames = (color = :red,),
    file_contents = (color = :light_black,),
    signature = (color = :light_black, format = true, highlight = true),
    source = (color = :normal, bold = true, highlight = true),
    line_range = (before = 0, after = 5),
    charset = :unicode,
)
const THEME = Ref{Any}(DEFAULT_THEME)

current_theme() = THEME[]
set_theme!(nt::NamedTuple) = THEME[] = nt
set_theme!(; kws...) = set_theme!(_nt(kws))

_nt(kws) = NamedTuple{Tuple(keys(kws))}(values(kws))
reset_theme!() = set_theme!(DEFAULT_THEME)

adjust_theme!(nt::NamedTuple) = set_theme!(merge(current_theme(), nt))
adjust_theme!(; kws...) = adjust_theme!(_nt(kws))

get_theme(key) = get(NamedTuple, current_theme(), key)
get_theme(key, default) = get(current_theme(), key, default)

function style(str; kws...)
    sprint(; context = :color => true) do io
        printstyled(io, str; bold = get(kws, :bold, false), color = get(kws, :color, :normal))
    end
end
style(str, key::Symbol) = style(str; get_theme(key)...)


#
# Stackframe Wrapping.
#

struct StackFrameWrapper
    sf::StackTraces.StackFrame
    n::Int
    StackFrameWrapper(tuple) = new(tuple...)
end

function Base.show(io::IO, s::StackFrameWrapper)
    func = style(s.sf.func, :function_name)
    file = rewrite_path(s.sf.file)
    dir, file = dirname(file), basename(file)
    file = style(file, :filename)
    dir = style(joinpath(dir, ""), :directory)
    line = style(s.sf.line, :line_number)
    repeated = s.n > 1 ? style("x $(s.n)", :repeated_frames) : ""
    print(io, strip("$func $dir$file:$line $repeated"))
end

function rewrite_path(path)
    fn(path, replacer) = replace(String(path), replacer; count = 1)
    path = fn(path, normpath(Sys.BUILD_STDLIB_PATH) => "@stdlib")
    path = fn(path, normpath(Sys.STDLIB) => "@stdlib")
    path = fn(path, homedir() => "~")
    return path
end

function find_source(file)
    # Binary versions of Julia have the wrong stdlib path, fix it.
    file = replace(string(file), normpath(Sys.BUILD_STDLIB_PATH) => Sys.STDLIB; count = 1)
    return Base.find_source_file(file)
end

#
# Explorer.
#

struct CapturedError
    err::Any
    bt::Any
end

Base.show(io::IO, ce::CapturedError) = showerror(io, ce.err, ce.bt)

explore(err::CapturedError) = explore(stdout, err)

function explore(io::IO, err::CapturedError; interactive = true)
    # Give a printout of the actual error message prior to launching tree
    # explorer since it's probably useful to have.
    println(io, sprint(showerror, err.err, context = :color => true))

    # Use the default cleaning functionality from Base. No need to reinvent.
    clean = Base.process_backtrace(err.bt)
    wrapped = StackFrameWrapper.(clean)

    toplevel = findfirst(s -> StackTraces.is_top_level_frame(s.sf), wrapped)
    toplevel = toplevel === nothing ? length(wrapped) : toplevel
    user_frames = wrapped[1:toplevel]
    system_frames = wrapped[toplevel+1:end]

    root = Node{Any}("(stacktrace)")

    function make_nodes(root_node, frames; fold = false)
        for (nth, frame_group) in enumerate(aggregate_modules(frames))
            m = module_of(first(frame_group))
            if m === :unknown
                for frame in frame_group
                    fold!(Node{Any}(frame, root_node))
                end
            else
                name =
                    m === :inlined ? style("[inlined]", :inlined_frames) :
                    m === :toplevel ? style("[top-level]", :toplevel_frames) :
                    is_from_stdlib(m) ? style("$(m)", :stdlib_module) :
                    is_from_base(m) ? style("$(m)", :base_module) :
                    is_from_core(m) ? style("$(m)", :core_module) :
                    is_from_package(m) ? style("$(m)", :package_module) :
                    style("$(m)", :unknown_module)

                node = Node{Any}(name, root_node)
                for frame in frame_group
                    current = Node{Any}(frame, node)
                    fold!(current)
                    # Formatted signature for the frame:
                    if !StackTraces.is_top_level_frame(frame.sf)
                        let lines = _formatted_signature(frame)
                            if !isempty(lines)
                                sig = Node{Any}(style("signature", :signature), current)
                                fold!(sig)
                                for line in lines
                                    Node{Any}(line, sig)
                                end
                            end
                        end
                    end
                    # Source code for the frame:
                    let lines = _lines_around(frame)
                        if !isempty(lines)
                            src = Node{Any}(style("source", :source), current)
                            for line in lines
                                Node{Any}(line, src)
                            end
                        end
                    end
                end
                # Hide any of the following by default:
                if m in (:inlined, :toplevel) ||
                   is_from_stdlib(m) ||
                   is_from_base(m) ||
                   is_from_core(m) ||
                   fold
                    fold!(node)
                end
                # Always open up the very first node, unless it's a toplevel.
                if nth === 1 && m !== :toplevel
                    unfold!(node)
                end
            end
        end
    end

    user_nodes = Node{Any}(style("(user)", :user_stack), root)
    make_nodes(user_nodes, user_frames)

    system_nodes = Node{Any}(style("(system)", :system_stack), root)
    make_nodes(system_nodes, system_frames; fold = true)
    fold!(system_nodes)

    menu = TreeMenu(root; dynamic = true, maxsize = 30)
    result = interactive ? TerminalMenus.request(menu; cursor = 3) : user_nodes
    result === nothing && return

    actions = [
        "clipboard" =>
            () -> (maybe_clipboard(sprint(showerror, err.err, err.bt[1:toplevel])); nothing),
        "print" => () -> (showerror(io, err.err, err.bt[1:toplevel]); nothing),
        "stacktrace" => () -> clean,
        "exception" => () -> err.err,
        "backtrace" => () -> err.bt,
    ]

    data = result.data
    extras = []
    if isa(data, StackFrameWrapper)
        file, line = data.sf.file, data.sf.line
        file = find_source(file)
        if file !== nothing && isfile(file)
            file, line
            extras = ["edit" => () -> (edit(file, line); nothing), "retry" => () -> true]
            has_debugger() && push!(extras, "breakpoint" => () -> breakpoint(file, line))
            push!(extras, "less" => () -> (less(file, line); nothing))
            actions = vcat(extras, actions)
        end
        if isdefined(data.sf, :linfo)
            mi = data.sf.linfo
            if isa(mi, Core.MethodInstance)
                extras = []
                if has_cthulhu()
                    push!(extras, "ascend" => () -> ascend(mi))
                    push!(extras, "descend" => () -> descend(mi))
                end
                if has_jet()
                    push!(extras, "JET" => () -> report_call(mi))
                end
                actions = vcat(extras, actions)
            end
        end
    end

    result =
        interactive ?
        request(MultiSelectMenu(first.(actions); charset = get_theme(:charset, :unicode))) :
        collect(1:length(actions))
    choice = sort(collect(result))
    if !isempty(choice)
        output = []
        for (name, func) in actions[choice]
            out = func()
            out === nothing || push!(output, Symbol(name) => out)
        end
        isempty(output) || return NamedTuple{Tuple(first.(output))}(last.(output))
    end
    return nothing
end

function _lines_around(s::StackFrameWrapper)
    file, line = s.sf.file, s.sf.line
    file = find_source(file)
    if file !== nothing && isfile(file)
        lines = readlines(file)
        range = get_theme(:line_range)
        above = max(1, line - get(range, :before, 0))
        below = min(line + get(range, :after, 5), length(lines))
        highlighter =
            get(get_theme(:source), :highlight, true) === true ? highlight :
            s -> style(s, :file_contents)
        return highlighter.(lines[above:below])
    else
        return String[]
    end
end

function _formatted_signature(s::StackFrameWrapper)
    str = String(rsplit(string(s.sf), " at "; limit = 2)[1])
    str = replace(str, "#unused#" => "")
    formatter = get(get_theme(:signature), :format, true) === true ? format_julia_source : identity
    highlighter =
        get(get_theme(:signature), :highlight, true) === true ? highlight :
        s -> style(s, :file_contents)
    fmt = highlighter(formatter(str))
    return collect(eachline(IOBuffer(fmt)))
end

# Just give up when there is no clipboard available.
function maybe_clipboard(str)
    try
        clipboard(str)
    catch err
        @warn "Could not find a clipboard."
    end
end

rootmodule(m::Module) = m === Base ? m : m === parentmodule(m) ? m : rootmodule(parentmodule(m))
rootmodule(::Any) = nothing
modulepath(m::Module) = string(pkgdir(m))
modulepath(other) = ""

is_from_stdlib(m) = startswith(modulepath(rootmodule(m)), Sys.STDLIB)
is_from_base(m) = rootmodule(m) === Base
is_from_core(m) = rootmodule(m) === Core
is_from_package(m) = (r = rootmodule(m); !is_from_core(r) && !is_from_base(r) && !is_from_stdlib(r))

module_of(sf) =
    sf.sf.inlined ? :inlined :
    sf.sf.func === Symbol("top-level scope") ? :toplevel :
    isa(sf.sf.linfo, Core.MethodInstance) ? sf.sf.linfo.def.module : :unknown

aggregate_modules(stacktrace) = IterTools.groupby(module_of, stacktrace)


#
# REPL hook.
#

const ENABLED = Ref(true)

"""
Turn interactive errors on or off.
"""
toggle() = ENABLED[] = !ENABLED[]

is_toggle_expr(expr) = Meta.isexpr(expr, :call, 1) && expr.args[1] === :toggle

is_retry(::Nothing) = false
is_retry(nt::NamedTuple) = haskey(nt, :retry) && nt.retry === true

maybe_retry(out, expr) = is_retry(out) ? Core.eval(Main, _ast_transforms(expr)) : out

function _ast_transforms(ast)
    if isdefined(Base, :active_repl_backend)
        for xf in Base.active_repl_backend.ast_transforms
            ast = Base.invokelatest(xf, ast)
        end
    end
    return ast
end

function wrap_errors(expr)
    if ENABLED[] && !is_toggle_expr(expr)
        quote
            try
                $(Expr(:toplevel, expr))
            catch e
                $(maybe_retry)(
                    $(explore)(($CapturedError)(e, catch_backtrace())),
                    $(Expr(:quote, expr)),
                )
            end
        end
    else
        expr
    end
end

function setup_repl()
    # Skip REPL setup if we are precompiling. Avoids warnings in precompilation.
    ccall(:jl_generating_output, Cint, ()) == 1 && return nothing

    @async begin
        done = false
        for _ = 1:10
            if isdefined(Base, :active_repl_backend)
                backend = Base.active_repl_backend
                if isdefined(backend, :ast_transforms)
                    pushfirst!(backend.ast_transforms, wrap_errors)
                    done = true
                    break
                end
            end
            sleep(0.5)
        end
        done || @warn "Could not start `InteractiveErrors` REPL hook."
    end
end


#
# Extensions, these get extended in the `/ext` modules.
#

has_cthulhu(args...) = false
ascend(args...) = @warn "`import Cthulhu` to enable `ascend` action."
descend(args...) = @warn "`import Cthulhu` to enable `descend` action."

has_debugger(args...) = false
breakpoint(args...) = @warn "`import Debugger` to enable `breakpoint` action."

has_jet(args...) = false
report_call(args...) = @warn "`import JET` to enable `report_call` action."

has_juliaformatter(args...) = false
format_julia_source(source) = source

has_ohmyrepl(args...) = false
highlight(source) = style(source, :file_contents)

#
# Module Initialisation.
#

function __init__()
    setup_repl()
    PackageExtensionCompat.@require_extensions
end

PrecompileTools.@compile_workload begin
    try
        div(1, 0)
    catch error
        explore(IOBuffer(), CapturedError(error, catch_backtrace()); interactive = false)
    end
end

end # module
