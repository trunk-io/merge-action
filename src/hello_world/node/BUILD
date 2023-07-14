load("//toolchain/node:defs.bzl", "trunk_js_binary", "trunk_ts_lib")

trunk_ts_lib(
    name = "lib",
    srcs = ["lib.ts"],
)

trunk_ts_lib(
    name = "app",
    srcs = ["app.ts"],
    deps = [
        ":lib",
    ],
)

trunk_js_binary(
    name = "bin",
    data = [":app"],
    entry_point = "app.js",
)
