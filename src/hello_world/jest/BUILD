load("//toolchain/node:defs.bzl", "trunk_js_binary", "trunk_ts_lib", "trunk_ts_test")

trunk_ts_lib(
    name = "lib",
    srcs = ["test.ts"],
    deps = [
        "//:node_modules/@types/jest",
        "//:node_modules/jest",
        "//:node_modules/jest-cli",
    ],
)

trunk_js_binary(
    name = "bin",
    data = [":lib"],
    entry_point = "test.js",
)

trunk_ts_test(
    name = "test",
    data = [":bin"],
)
