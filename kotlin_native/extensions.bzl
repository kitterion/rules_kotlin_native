load("//kotlin_native:toolchains.bzl", "kt_native_register_toolchains")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _kotlin_native_impl(module_ctx):
    root = None
    for module in module_ctx.modules:
        if module.is_root:
            root = module

    if root == None or not root.tags.toolchain:
        kt_native_register_toolchains()
    else:
        for toolchain in root.tags.toolchain:
            kt_native_register_toolchains(
                version = toolchain.version,
                language_version = toolchain.language_version,
                api_version = toolchain.api_version,
            )

    version = "2.1.21-2.0.1"
    http_archive(
        name = "kotlin_native_ksp",
        urls = ["https://github.com/google/ksp/releases/download/%s/artifacts.zip" % version],
        integrity = "sha256-ROlluwZ7K7XNkYTassPepuPqt0fTQcB2RbtMiPCeScg=",
        build_file_content = """\
FILES = [
    "symbol-processing-aa",
    "symbol-processing-aa-embeddable",
    "symbol-processing-api",
    "symbol-processing-cmdline",
    "symbol-processing-common-deps",
    "symbol-processing-gradle-plugin",
]

[java_import(
    name = file,
    jars = ["com/google/devtools/ksp/{{name}}/{version}/{{name}}-{version}.jar".format(name = file)],
    visibility = ["//visibility:public"],
) for file in FILES]
""".format(version = version),
    )

_toolchain_tag = tag_class(
    attrs = {
        "version": attr.string(),
        "language_version": attr.string(),
        "api_version": attr.string(),
    },
)

kotlin_native = module_extension(
    implementation = _kotlin_native_impl,
    tag_classes = {
        "toolchain": _toolchain_tag,
    },
)
