load("//toolchain/docker:defs.bzl", "trunk_container_image", "trunk_container_run_and_commit", "trunk_nodejs_container_image")
load("//toolchain/node:defs.bzl", "trunk_js_binary", "trunk_ts_lib", "trunk_ts_test")

package(
    default_visibility = ["//visibility:private"],
)

trunk_container_run_and_commit(
    name = "nodejs_image_with_utils",
    commands = [
        "apt update && apt install -y " + " ".join([
            "curl",
            "jq",
        ]) + " && rm -rf /var/lib/apt/lists/*",
    ],
    image = "@debian11//image",
)

trunk_ts_lib(
    name = "lib",
    srcs = ["upload.test.ts"],
    deps = [
        "//:node_modules/@types/chai",
        "//:node_modules/@types/chai-as-promised",
        "//:node_modules/@types/express",
        "//:node_modules/@types/lodash",
        "//:node_modules/@types/mocha",
        "//:node_modules/chai",
        "//:node_modules/chai-as-promised",
        "//:node_modules/express",
        "//:node_modules/http-status-codes",
        "//:node_modules/lodash",
        "//:node_modules/mocha",
    ],
)

trunk_js_binary(
    name = "bin",
    data = [":lib"],
    entry_point = "upload.test.js",
)

trunk_ts_test(
    name = "test",
    srcs = ["upload.test.ts"],
    data = [":bin"],
)

# Dockerize the Test
trunk_nodejs_container_image(
    name = "nodejs_test",
    testonly = True,
    args = ["src/**/upload.test.ts"],
    base = ":nodejs_image_with_utils",
    binary = ":test",
)

trunk_container_image(
    name = "test_image",
    testonly = True,
    base = ":nodejs_test",
    cmd = ["__main__/tests/upload.test.js"],
    entrypoint = "bash /app/{}/test".format(package_name()).split(" "),
    files = ["//src/scripts"],
    workdir = "/app/{}/test.runfiles".format(package_name()),
)
