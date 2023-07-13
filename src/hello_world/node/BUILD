load("@aspect_rules_js//js:defs.bzl", "js_binary")
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

ts_project(
    name = "lib",
    srcs = glob(["*.ts"]),
    tsconfig = "//:tsconfig",
)

js_binary(
    name = "app",
    data = ["//src/hello_world/node:lib"],
    entry_point = "app.ts",
)
