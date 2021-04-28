using Test, InteractiveErrors

@testset "InteractiveErrors" begin
    IE = InteractiveErrors

    @test IE.rootmodule(Main) === Main
    @test IE.rootmodule(Base) === Base
    @test IE.rootmodule(Core) === Core
    @test IE.rootmodule(InteractiveErrors) === InteractiveErrors
    @test IE.rootmodule(Base.Math) === Base

    @test IE.is_from_stdlib(Test)
    @test !IE.is_from_base(Test)
    @test IE.is_from_base(Base)
    @test !IE.is_from_package(Base)
    @test IE.is_from_package(InteractiveErrors)
    @test !IE.is_from_core(InteractiveErrors)
    @test IE.is_from_core(Core)

    build = joinpath(normpath(Sys.BUILD_STDLIB_PATH), "Test", "src", "Test.jl")
    stdlib = joinpath(normpath(Sys.STDLIB), "Test", "src", "Test.jl")
    package = @__FILE__
    @test isfile(InteractiveErrors.find_source(build))
    @test isfile(InteractiveErrors.find_source(stdlib))
    @test isfile(InteractiveErrors.find_source(package))
    @test startswith(InteractiveErrors.rewrite_path(build), "@stdlib")
    @test startswith(InteractiveErrors.rewrite_path(stdlib), "@stdlib")

    @test isa(IE.wrap_errors(:(1 + 1)), Expr)
    @test isa(IE.wrap_errors(:(toggle())), Expr)
    toggle()
    @test isa(IE.wrap_errors(:(1 + 1)), Expr)
    @test isa(IE.wrap_errors(:(toggle())), Expr)
    toggle()

    @test IE.style("func", :function_name) == "\e[0m\e[1mfunc\e[22m"
    @test isa(IE.adjust_theme!(function_name = (color = :yellow, bold = false)), NamedTuple)
    @test IE.style("func", :function_name) == "\e[33mfunc\e[39m"
    @test isa(IE.current_theme(), NamedTuple)

    try
        div(1, 0)
    catch err
        ce = IE.CapturedError(err, catch_backtrace())
        io = IOBuffer()
        nt = IE.explore(io, ce; interactive = false)
        str = String(take!(io))
        @test !isempty(str)
        @test contains(str, "DivideError:")
        @test isa(nt, NamedTuple)
        @test collect(keys(nt)) == [:stacktrace, :exception, :backtrace]
        @test isa(nt.exception, DivideError)
        @test !isempty(nt.stacktrace)
        @test !isempty(nt.backtrace)
    end

    @test !IE.has_cthulhu()
    @test !IE.has_debugger()
    @test !IE.has_jet()

    using Cthulhu, Debugger, JET

    @test IE.has_cthulhu()
    @test IE.has_debugger()
    @test IE.has_jet()

    try
        sqrt(-1)
    catch err
        ce = IE.CapturedError(err, catch_backtrace())
        io = IOBuffer()
        nt = IE.explore(io, ce; interactive = false)
        str = String(take!(io))
        @test !isempty(str)
        @test contains(str, "DomainError")
        @test isa(nt, NamedTuple)
        @test collect(keys(nt)) == [:stacktrace, :exception, :backtrace]
        @test isa(nt.exception, DomainError)
        @test !isempty(nt.stacktrace)
        @test !isempty(nt.backtrace)
    end
end
