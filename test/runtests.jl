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

    using Cthulhu, Debugger

    @test IE.has_cthulhu()
    @test IE.has_debugger()

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
