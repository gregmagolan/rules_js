load("@aspect_bazel_lib//lib:run_binary.bzl", "run_binary")
load("@aspect_bazel_lib//lib:copy_directory.bzl", "copy_directory")

def postinstall(name, src, package_name):
    """Run postinstall on an npm package and provide a TreeArtifact containing
    the postinstalled package.

    Args:
        name: Name of the rule
        src: A label pointing to the npm package directory
        package_name: the name of the npm package, e.g. "@foo/bar"
    """
    run_binary(
        name = "_%s" % name,
        srcs = [src],
        args = [ "$(location %s)" % src, "$(@D)"],
        tool = "@aspect_rules_js//js:postinstall",
        output_dir = True,
    )

    # The directory name must match the package in order for node to find it under
    # NODE_PATH=runfiles/[out]
    copy_directory(
        name = name,
        src = ":_%s" % name,
        out = package_name,
    )