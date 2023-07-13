load("@aspect_rules_js//js:defs.bzl", "js_binary")
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

ts_project(
    name = "lib",
    srcs = ["lib.ts"],
    composite = True,
    declaration = True,
    source_map = True,
    tsconfig = "//:root_tsconfig",
)

ts_project(
    name = "app",
    srcs = ["app.ts"],
    composite = True,
    declaration = True,
    source_map = True,
    tsconfig = "//:root_tsconfig",
    deps = [":lib"],
)

js_binary(
    name = "bin",
    entry_point = "app.ts",
    expected_exit_code = 0,
)
