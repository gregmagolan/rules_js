"wrapper macro for npm_import repository rule"

load("//js/private:npm_import.bzl", lib = "npm_import")
load("//js/private:npm_utils.bzl", "npm_utils")

_npm_import = repository_rule(
    implementation = lib.implementation,
    attrs = lib.attrs,
)

def npm_import(
    name,
    package_name,
    package_version,
    integrity,
    deps = [],
    transitive = False,
    patches = [],
    patch_args = ["-p0"]):
    """Import a single npm package into Bazel.

    Normally you'd want to use `translate_pnpm_lock` to import all your packages at once.
    It generates `npm_import` rules.
    You can create these manually if you want to have exact control.

    Bazel will only fetch the given package from an external registry if the package is
    required for the user-requested targets to be build/tested.
    The package will be exposed as a [`nodejs_package`](./nodejs_package) rule in a repository
    with a default name `@npm_[package name]-[version]`, as the default target in that repository.
    (Characters in the package name which are not legal in Bazel repository names are converted to underscore.)

    This is a repository rule, which should be called from your `WORKSPACE` file
    or some `.bzl` file loaded from it. For example, with this code in `WORKSPACE`:

    ```starlark
    npm_import(
        package = "@types/node",
        version = "15.12.2",
        integrity = "sha512-zjQ69G564OCIWIOHSXyQEEDpdpGl+G348RAKY0XXy9Z5kU9Vzv1GMNnkar/ZJ8dzXB3COzD9Mo9NtRZ4xfgUww==",
    )
    ```

    you can use the label `@npm__types_node-15.12.2` in your BUILD files to reference the package.

    > This is similar to Bazel rules in other ecosystems named "_import" like
    > `apple_bundle_import`, `scala_import`, `java_import`, and `py_import`
    > `go_repository` is also a model for this rule.

    The name of this repository should contain the version number, so that multiple versions of the same
    package don't collide.
    (Note that the npm ecosystem always supports multiple versions of a library depending on where
    it is required, unlike other languages like Go or Python.)

    To change the proxy URL we use to fetch, configure the Bazel downloader:
    1. Make a file containing a rewrite rule like

       rewrite (registry.nodejs.org)/(.*) artifactory.build.internal.net/artifactory/$1/$2

    1. To understand the rewrites, see [UrlRewriterConfig] in Bazel sources.

    1. Point bazel to the config with a line in .bazelrc like
        common --experimental_downloader_config=.bazel_downloader_config

    [UrlRewriterConfig]: https://github.com/bazelbuild/bazel/blob/4.2.1/src/main/java/com/google/devtools/build/lib/bazel/repository/downloader/UrlRewriterConfig.java#L66

    Args:
        name: name of the external repository
        package_name: npm package name, such as `acorn` or `@types/node`
        package_version: version of the npm package, such as `8.4.0`
        integrity: Expected checksum of the file downloaded, in Subresource Integrity format.
            This must match the checksum of the file downloaded.

            This is the same as appears in the pnpm-lock.yaml, yarn.lock or package-lock.json file.

            It is a security risk to omit the checksum as remote files can change.
            At best omitting this field will make your build non-hermetic.
            It is optional to make development easier but should be set before shipping.
        deps: other npm packages this one depends on.
        transitive: If True, this is a transitive npm dependency which is not linked as a top-level node_module
        patches: patch files to apply onto the downloaded npm package.
        patch_args: arguments to pass to the patch tool.
            Defaults to `-p0`, but `-p1` will usually be needed for patches generated by git.
    """

    _npm_import(
        name = name,
        package_name = package_name,
        package_version = package_version,
        integrity = integrity,
        deps = deps,
        transitive = transitive,
        patches = patches,
        patch_args = patch_args,
    )
