load("@aspect_rules_js//js:defs.bzl", "js_binary", "js_image_layer")
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load(
    "@io_bazel_rules_docker//container:container.bzl",
    "container_image",
    "container_layer",
)

ts_project(
    name = "lib",
    srcs = glob(["*.ts"]),
    tsconfig = "//:tsconfig",
)

### NodeJS Layer

### App Layer
js_binary(
    name = "app",
    data = ["//src/hello_world/docker:lib"],
    entry_point = "app.ts",
)

js_image_layer(
    name = "js_app_layer",
    binary = ":app",
)

container_layer(
    name = "app_layer",
    files = [":js_app_layer"],
)

### Final Image
container_image(
    name = "docker_image",
    base = "@linux_base//image",
    # tags = ["latest"],
    cmd = [
        "/bin/sh",
        "-c",
        "app.sh",
    ],
    layers = ["//src/hello_world/docker:app_layer"],
)
