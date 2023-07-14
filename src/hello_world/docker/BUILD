load("//toolchain/docker:defs.bzl", "trunk_container_image", "trunk_nodejs_container_image")
load("//toolchain/node:defs.bzl", "trunk_js_binary", "trunk_ts_lib")

trunk_ts_lib(
    name = "lib",
    srcs = ["app.ts"],
)

trunk_js_binary(
    name = "bin",
    data = [":lib"],
    entry_point = "app.js",
)

trunk_nodejs_container_image(
    name = "nodejs_image",
    args = ["src/**/app.ts"],
    binary = ":bin",
)

trunk_container_image(
    name = "image",
    base = ":nodejs_image",
    cmd = ["src/**/app.ts"],
    entrypoint = "bash /app/{}/bin".format(package_name()).split(" "),
    workdir = "/app/{}/bin.runfiles".format(package_name()),
)
