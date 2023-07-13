load("@aspect_rules_ts//ts:defs.bzl", "ts_config")
load("@npm//:defs.bzl", "npm_link_all_packages")

# Expose tsconfig to all subpackages (e.g. ts_project macros).
ts_config(
    name = "root_tsconfig",
    src = "tsconfig.json",
    visibility = ["//visibility:public"],
)

# Expose all `node_modules/**` as build targets (e.g. //:node_modules/mocha).
npm_link_all_packages(name = "node_modules")
