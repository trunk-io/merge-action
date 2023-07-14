load("@aspect_rules_js//js:defs.bzl", "js_binary")
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")
load("@npm//:mocha/package_json.bzl", mocha_bin = "bin")

def trunk_ts_lib(name, srcs, deps = []):
    ts_project(
        name = name,
        srcs = srcs,
        deps = deps,
        declaration = True,
        resolve_json_module = True,
        source_map = True,
        tsconfig = "//:root_tsconfig",
    )

def trunk_js_binary(name, data, entry_point):
    js_binary(
        name = name,
        data = data,
        entry_point = entry_point,
        expected_exit_code = 0,
    )

def trunk_ts_test(name, srcs, data, tags = [], node_options = []):
    args = []
    for src in srcs:
        if not src.endswith(".ts"):
            fail("All test files must end with .ts: {}".format(src))
        args.append(native.package_name() + "/" + src[:-3] + ".js")

    mocha_bin.mocha_test(
        name = name,
        args = args,
        data = data,
        tags = tags,
        testonly = True,
        timeout = "short",
        node_options = node_options,
        log_level = "debug",
        patch_node_fs = False,
    )
