load("//toolchain/docker:defs.bzl", "trunk_container_image", "trunk_nodejs_container_image")
load("//toolchain/node:defs.bzl", "trunk_js_binary", "trunk_ts_lib", "trunk_ts_test")

trunk_ts_lib(
    name = "lib",
    srcs = ["test.ts"],
    deps = [
        "//:node_modules/@types/chai",
        "//:node_modules/@types/mocha",
        "//:node_modules/chai",
        "//:node_modules/mocha",
    ],
)

trunk_js_binary(
    name = "bin",
    data = [":lib"],
    entry_point = "test.js",
)

trunk_ts_test(
    name = "test",
    srcs = ["test.ts"],
    data = [":bin"],
)

# Test Dockerizing the Test
trunk_nodejs_container_image(
    name = "nodejs_test",
    testonly = True,
    args = ["src/**/test.ts"],
    binary = ":test",
)

trunk_container_image(
    name = "test_image",
    testonly = True,
    base = ":nodejs_test",
    cmd = ["__main__/src/hello_world/mocha/test.js"],
    entrypoint = "bash /app/{}/test".format(package_name()).split(" "),
    workdir = "/app/{}/test.runfiles".format(package_name()),
)
