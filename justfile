fmt:
    runic --inplace .

fmt-check:
    runic --check .

changelog:
    julia --project=.ci .ci/changelog.jl
