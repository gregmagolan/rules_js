<!-- Generated with Stardoc: http://skydoc.bazel.build -->

repository rules for importing packages from npm

<a id="#translate_package_lock"></a>

## translate_package_lock

<pre>
translate_package_lock(<a href="#translate_package_lock-name">name</a>, <a href="#translate_package_lock-package_lock">package_lock</a>, <a href="#translate_package_lock-patch_args">patch_args</a>, <a href="#translate_package_lock-patches">patches</a>, <a href="#translate_package_lock-repo_mapping">repo_mapping</a>)
</pre>

Repository rule to generate npm_import rules from package-lock.json file.

The npm lockfile format includes all the information needed to define npm_import rules,
including the integrity hash, as calculated by the package manager.

Instead of manually declaring the `npm_imports`, this helper generates an external repository
containing a helper starlark module `repositories.bzl`, which supplies a loadable macro
`npm_repositories`. This macro creates an `npm_import` for each package.

The generated repository also contains BUILD files declaring targets for the packages
listed as `dependencies` or `devDependencies` in `package.json`, so you can declare
dependencies on those packages without having to repeat version information.

Bazel will only fetch the packages which are required for the requested targets to be analyzed.
Thus it is performant to convert a very large package-lock.json file without concern for
users needing to fetch many unnecessary packages.

**Setup**

In `WORKSPACE`, call the repository rule pointing to your package-lock.json file:

```starlark
load("@aspect_rules_js//js:npm_import.bzl", "translate_package_lock")

# Read the package-lock.json file to automate creation of remaining npm_import rules
translate_package_lock(
    # Creates a new repository named "@npm_deps"
    name = "npm_deps",
    package_lock = "//:package-lock.json",
)
```

Next, there are two choices, either load from the generated repo or check in the generated file.
The tradeoffs are similar to
[this rules_python thread](https://github.com/bazelbuild/rules_python/issues/608).

1. Immediately load from the generated `repositories.bzl` file in `WORKSPACE`.
This is similar to the 
[`pip_parse`](https://github.com/bazelbuild/rules_python/blob/main/docs/pip.md#pip_parse)
rule in rules_python for example.
It has the advantage of also creating aliases for simpler dependencies that don't require
spelling out the version of the packages.
However it causes Bazel to eagerly evaluate the `translate_package_lock` rule for every build,
even if the user didn't ask for anything JavaScript-related.

```starlark
load("@npm_deps//:repositories.bzl", "npm_repositories")

npm_repositories()
```

In BUILD files, declare dependencies on the packages using the same external repository.

Following the same example, this might look like:

```starlark
nodejs_test(
    name = "test_test",
    data = ["@npm_deps//@types/node"],
    entry_point = "test.js",
)
```

2. Check in the `repositories.bzl` file to version control, and load that instead.
This makes it easier to ship a ruleset that has its own npm dependencies, as users don't
have to install those dependencies. It also avoids eager-evaluation of `translate_package_lock`
for builds that don't need it.
This is similar to the [`update-repos`](https://github.com/bazelbuild/bazel-gazelle#update-repos)
approach from bazel-gazelle.

In a BUILD file, use a rule like
[write_source_files](https://github.com/aspect-build/bazel-lib/blob/main/docs/write_source_files.md)
to copy the generated file to the repo and test that it stays updated:

```starlark
write_source_files(
    name = "update_repos",
    files = {
        "repositories.bzl": "@npm_deps//:repositories.bzl",
    },
)
```

Then in `WORKSPACE`, load from that checked-in copy or instruct your users to do so.
In this case, the aliases are not created, so you get only the `npm_import` behavior
and must depend on packages with their versioned label like `@npm__types_node-15.12.2`.


**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="translate_package_lock-name"></a>name |  A unique name for this repository.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| <a id="translate_package_lock-package_lock"></a>package_lock |  The package-lock.json file.<br><br>        It should use the lockfileVersion 2, which is produced from npm 7 or higher.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| <a id="translate_package_lock-patch_args"></a>patch_args |  A map of package names or package names with their version (e.g., "my-package" or "my-package@v1.2.3")         to a label list arguments to pass to the patch tool. Defaults to -p0, but -p1 will         usually be needed for patches generated by git. If patch args exists for a package         as well as a package version, then the version-specific args will be appended to the args for the package.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> List of strings</a> | optional | {} |
| <a id="translate_package_lock-patches"></a>patches |  A map of package names or package names with their version (e.g., "my-package" or "my-package@v1.2.3")         to a label list of patches to apply to the downloaded npm package. Paths in the patch         file must start with <code>extract_tmp/package</code> where <code>package</code> is the top-level folder in         the archive on npm. If the version is left out of the package name, the patch will be         applied to every version of the npm package.   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> List of strings</a> | optional | {} |
| <a id="translate_package_lock-repo_mapping"></a>repo_mapping |  A dictionary from local repository name to global repository name. This allows controls over workspace dependency resolution for dependencies of this repository.&lt;p&gt;For example, an entry <code>"@foo": "@bar"</code> declares that, for any time this repository depends on <code>@foo</code> (such as a dependency on <code>@foo//some:target</code>, it should actually resolve that dependency within globally-declared <code>@bar</code> (<code>@bar//some:target</code>).   | <a href="https://bazel.build/docs/skylark/lib/dict.html">Dictionary: String -> String</a> | required |  |


<a id="#npm_import"></a>

## npm_import

<pre>
npm_import(<a href="#npm_import-integrity">integrity</a>, <a href="#npm_import-package">package</a>, <a href="#npm_import-version">version</a>, <a href="#npm_import-deps">deps</a>, <a href="#npm_import-name">name</a>, <a href="#npm_import-patches">patches</a>, <a href="#npm_import-patch_args">patch_args</a>)
</pre>

Import a single npm package into Bazel.

Normally you'd want to use `translate_package_lock` to import all your packages at once.
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
    integrity = "sha512-zjQ69G564OCIWIOHSXyQEEDpdpGl+G348RAKY0XXy9Z5kU9Vzv1GMNnkar/ZJ8dzXB3COzD9Mo9NtRZ4xfgUww==",
    package = "@types/node",
    version = "15.12.2",
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


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="npm_import-integrity"></a>integrity |  Expected checksum of the file downloaded, in Subresource Integrity format. This must match the checksum of the file downloaded.<br><br>This is the same as appears in the yarn.lock or package-lock.json file.<br><br>It is a security risk to omit the checksum as remote files can change. At best omitting this field will make your build non-hermetic. It is optional to make development easier but should be set before shipping.   |  none |
| <a id="npm_import-package"></a>package |  npm package name, such as <code>acorn</code> or <code>@types/node</code>   |  none |
| <a id="npm_import-version"></a>version |  version of the npm package, such as <code>8.4.0</code>   |  none |
| <a id="npm_import-deps"></a>deps |  other npm packages this one depends on.   |  <code>[]</code> |
| <a id="npm_import-name"></a>name |  the external repository generated to contain the package content. This argument may be omitted to get the default name documented above.   |  <code>None</code> |
| <a id="npm_import-patches"></a>patches |  patch files to apply onto the downloaded npm package. Paths in the patch file must start with <code>extract_tmp/package</code> where <code>package</code> is the top-level folder in the archive on npm.   |  <code>[]</code> |
| <a id="npm_import-patch_args"></a>patch_args |  arguments to pass to the patch tool. Defaults to -p0, but -p1 will usually be needed for patches generated by git.   |  <code>["-p0"]</code> |


