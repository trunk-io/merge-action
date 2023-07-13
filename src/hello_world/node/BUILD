load("@aspect_rules_js//js:defs.bzl", "js_binary")
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

ts_project(
    name = "lib",
    srcs = ["lib.ts"],
    declaration = True,
    resolve_json_module = True,
    source_map = True,
    tsconfig = "//:root_tsconfig",
)

ts_project(
    name = "app",
    srcs = ["app.ts"],
    declaration = True,
    resolve_json_module = True,
    source_map = True,
    tsconfig = "//:root_tsconfig",
    deps = [
        ":lib",
        "//:node_modules/@types/chai",
    ],
)

js_binary(
    name = "bin",
    data = [":app"],
    entry_point = "app.js",
    expected_exit_code = 0,
)
