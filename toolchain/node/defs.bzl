load("@aspect_rules_jest//jest:defs.bzl", "jest_test")
load("@aspect_rules_js//js:defs.bzl", "js_binary")
load("@aspect_rules_ts//ts:defs.bzl", "ts_project")

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

def trunk_ts_test(name, data):
    jest_test(
        name = name,
        data = data + [
            "//:node_modules/@types/jest",
            "//:node_modules/jest",
            "//:node_modules/jest-cli",
            "//:node_modules/jest-junit",
        ],
        node_modules = "//:node_modules",
        colors = True,
    )
