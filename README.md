# Bazel Kotlin Native rules

## Installation

Only bzlmod is supported right now. Pick the latest commit and add the following to your MODULE.bazel file

```python
bazel_dep(name = "rules_kotlin_native")
archive_override(
    module_name = "rules_kotlin_native",
    url = "https://github.com/bazelbuild/rules_kotlin/archive/<commit>.zip",
    strip_prefix = "rules_kotlin_native-<commit>",
)
```

### Customizing

You can customize the compiler version, the language version and the api version. See for example [here](https://kotlinlang.org/docs/compatibility-modes.html) for an explanation.

Note, that currently only a few compiler versions can be specified (2.0.21 and 2.1.21). Kotlin Native compiler has a few host-specific dependencies that it downloads on the first launch which doesn't quite work with bazel. To side-step this and to integrate with the bazel downloader, these dependencies are currently manually specified for each known compiler version. There are plans to support other versions including versions unknown to rules\_kotlin\_native.

```python
kotlin_native = use_extension("@rules_kotlin_native//kotlin_native:extensions.bzl", "kotlin_native")
kotlin_native.toolchain(
    version = "2.1.21",
    language_version = "2.0",
    api_version = "2.0",
)
```

# Overview

Supported rules are:
- `kt_native_library`
  ```python
  load("@rules_kotlin_native//kotlin_native:kt_native_library.bzl", "kt_native_library")

  kt_native_library(
      name = "lib",
      srcs = ["Lib.kt"],
  )
  ```
- `kt_native_binary`.
  ```python
  load("@rules_kotlin_native//kotlin_native:kt_native_binary.bzl", "kt_native_binary")

  kt_native_binary(
      name = "bin",
      srcs = ["Main.kt"],
      # Fully-qualified path to the main function. The default is "main".
      entry_point = "package.name.main",
      deps = [":lib"],
  )
  ```
- `kt_native_cinterop`. See [`examples/hello_world_cinterop`](examples/hello_world_cinterop)
  ```python
  load("@rules_kotlin_native//kotlin_native:kt_native_cinterop.bzl", "kt_native_cinterop")

  kt_native_cinterop(
      name = "hello_world_cinterop",
      src = "hello_world.def",
      # The supported deps are cc_library, swift_library, objc_library.
      # In fact, anything providing CcInfo or SwiftInfo should work.
      deps = [":hello_world_cc"],
  )
  ```
- `kt_native_static_framework`. Useful when building for apple platforms. Generates an apple framework that can be dependent on by swift or objc rules.
  ```python
  load("@rules_kotlin_native//kotlin_native:kt_native_static_framework.bzl", "kt_native_static_framework")

  kt_native_static_framework(
      name = "framework",
      # This is the name of the framework (and the generated header).
      bundle_name = "KotlinNative"
      # The targets in deps define what gets exported from the framework.
      deps = [
          "//lib_a",
          "//lib_b",
      ],
  )
  ```

## Compiler plugins
Compiler plugins from [rules\_kotlin](https://github.com/bazelbuild/rules_kotlin/blob/18d8be43c5b0fdeacb33fd6a968b07fc0a106b1e/README.md#kotlin-compiler-plugins) should work.

> [!CAUTION]
> Make sure you are using compatible versions of the Kotlin JVM compiler from rules\_kotlin and Kotlin Native compiler. Incompatibilities may and will cause weird build failures with the compiler crashing.

```python
kt_compile_plugin(
    name = "serialization_plugin",
    compile_phase = True,
    id = "org.jetbrains.kotlinx.serialization",
    stubs_phase = True,
    deps = [
        "@rules_kotlin//kotlin/compiler:kotlinx-serialization-compiler-plugin",
    ],
)

kt_native_library(
    ...
    plugins = [":serialization_plugin"],
)
```
