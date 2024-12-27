import Changelog

cd(dirname(@__DIR__)) do
    Changelog.generate(
        Changelog.CommonMark(),
        "CHANGELOG.md";
        repo="MichaelHatherly/InteractiveErrors.jl",
    )
end
