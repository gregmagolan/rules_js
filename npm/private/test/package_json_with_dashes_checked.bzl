"@generated by @aspect_rules_js//npm/private:npm_import.bzl for npm package webpack-bundle-analyzer@4.5.0_bufferutil@4.0.1"

load("@aspect_bazel_lib//lib:directory_path.bzl", _directory_path = "directory_path")
load("@aspect_rules_js//js:defs.bzl", _js_binary = "js_binary", _js_run_binary = "js_run_binary", _js_test = "js_test")

def _webpack_bundle_analyzer_internal(name, link_root_name, **kwargs):
    store_target_name = ".aspect_rules_js/{}/webpack-bundle-analyzer/4.5.0_bufferutil@4.0.1".format(link_root_name)
    _directory_path(
        name = "%s__entry_point" % name,
        directory = "@//:{}/dir".format(store_target_name),
        path = "lib/bin/analyzer.js",
    )
    _js_binary(
        name = "%s__js_binary" % name,
        entry_point = ":%s__entry_point" % name,
        data = ["@//:{}".format(store_target_name)],
    )
    _js_run_binary(
        name = name,
        tool = ":%s__js_binary" % name,
        **kwargs
    )

def _webpack_bundle_analyzer_test_internal(name, link_root_name, **kwargs):
    store_target_name = ".aspect_rules_js/{}/webpack-bundle-analyzer/4.5.0_bufferutil@4.0.1".format(link_root_name)
    _directory_path(
        name = "%s__entry_point" % name,
        directory = "@//:{}/dir".format(store_target_name),
        path = "lib/bin/analyzer.js",
    )
    _js_test(
        name = name,
        entry_point = ":%s__entry_point" % name,
        data = kwargs.pop("data", []) + ["@//:{}".format(store_target_name)],
        **kwargs
    )

def _webpack_bundle_analyzer_binary_internal(name, link_root_name, **kwargs):
    store_target_name = ".aspect_rules_js/{}/webpack-bundle-analyzer/4.5.0_bufferutil@4.0.1".format(link_root_name)
    _directory_path(
        name = "%s__entry_point" % name,
        directory = "@//:{}/dir".format(store_target_name),
        path = "lib/bin/analyzer.js",
    )
    _js_binary(
        name = name,
        entry_point = ":%s__entry_point" % name,
        data = kwargs.pop("data", []) + ["@//:{}".format(store_target_name)],
        **kwargs
    )

def webpack_bundle_analyzer(name, **kwargs):
    _webpack_bundle_analyzer_internal(name, "node_modules", **kwargs)

def webpack_bundle_analyzer_test(name, **kwargs):
    _webpack_bundle_analyzer_test_internal(name, "node_modules", **kwargs)

def webpack_bundle_analyzer_binary(name, **kwargs):
    _webpack_bundle_analyzer_binary_internal(name, "node_modules", **kwargs)

def bin_factory(link_root_name):
    # bind link_root_name using lambdas
    return struct(
        webpack_bundle_analyzer = lambda name, **kwargs: _webpack_bundle_analyzer_internal(name, link_root_name = link_root_name, **kwargs),
        webpack_bundle_analyzer_test = lambda name, **kwargs: _webpack_bundle_analyzer_test_internal(name, link_root_name = link_root_name, **kwargs),
        webpack_bundle_analyzer_binary = lambda name, **kwargs: _webpack_bundle_analyzer_binary_internal(name, link_root_name = link_root_name, **kwargs),
    )

bin = bin_factory("node_modules")
