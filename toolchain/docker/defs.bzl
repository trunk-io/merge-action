load("@aspect_rules_js//js:defs.bzl", "js_image_layer")
load("@io_bazel_rules_docker//container:container.bzl", "container_image", "container_layer")
load("@io_bazel_rules_docker//docker/util:run.bzl", "container_run_and_commit")

def trunk_container_image(name, tags = [], legacy_run_behavior = False, **kwargs):
    container_image(name = name, tags = tags, legacy_run_behavior = legacy_run_behavior, **kwargs)

def trunk_container_run_and_commit(name, tags = [], visibility = ["//visibility:public"], **kwargs):
    container_run_and_commit(
        name = name,
        tags = tags,
        visibility = visibility,
        **kwargs
    )

def trunk_nodejs_container_image(name, binary, tags = [], layers = [], base = "@debian11//image", visibility = ["//visibility:public"], testonly = False, **kwargs):
    layers_name = name + "_layers"
    js_image_layer(
        name = layers_name,
        binary = binary,
        root = "/app",
        visibility = visibility,
        testonly = testonly,
    )

    app_tar_name = name + "_app_tar"
    native.filegroup(
        name = app_tar_name,
        srcs = [layers_name],
        output_group = "app",
        visibility = visibility,
        testonly = testonly,
    )

    app_layer_name = name + "_app_layer"
    container_layer(
        name = app_layer_name,
        tars = [app_tar_name],
        visibility = visibility,
        testonly = testonly,
    )

    node_modules_tar_name = name + "_node_modules_tar"
    native.filegroup(
        name = node_modules_tar_name,
        srcs = [layers_name],
        output_group = "node_modules",
        visibility = visibility,
        testonly = testonly,
    )

    node_modules_layer_name = name + "_node_modules_layer"
    container_layer(
        name = node_modules_layer_name,
        tars = [node_modules_tar_name],
        visibility = visibility,
        testonly = testonly,
    )

    container_image(
        name = name,
        tags = tags,
        architecture = "amd64",
        base = base,
        layers = layers + [
            app_layer_name,
            node_modules_layer_name,
        ],
        visibility = visibility,
        testonly = testonly,
        **kwargs
    )
