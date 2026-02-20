load("//kotlin_native:versions.bzl",
    _VERSIONS = "VERSIONS",
    _URL_TEMPLATE = "URL_TEMPLATE",
    _STRIP_PREFIX_TEMPLATE = "STRIP_PREFIX_TEMPLATE",
)
load("//kotlin_native/internal:providers.bzl", _KtNativeStdlibInfo = "KtNativeStdlibInfo")

_NATIVE_TOOLCHAIN_TYPE = str(Label("//kotlin_native:toolchain_type"))
_NATIVE_STDLIB_TOOLCHAIN_TYPE =str(Label("//kotlin_native:stdlib_toolchain_type")) 

_NATIVE_PROXY_TEMPLATE = """
toolchain(
    name = "{toolchain_name}_{target}_stdlib_toolchain",
    exec_compatible_with = {exec_compatible_with},
    target_compatible_with = {target_compatible_with},
    toolchain = "@{compiler_repository}//:stdlib_toolchain_{target}",
    toolchain_type = "{stdlib_toolchain_type}",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "{toolchain_name}_{target}_toolchain",
    exec_compatible_with = {exec_compatible_with},
    target_compatible_with = {target_compatible_with},
    toolchain = "@{compiler_repository}//:toolchain_{target}",
    toolchain_type = "{toolchain_type}",
    visibility = ["//visibility:public"],
)
"""

def _kt_native_toolchain_proxy_impl(repository_ctx):
    content = ""
    for toolchain_name in repository_ctx.attr.toolchain_names:
        for target in repository_ctx.attr.toolchain_targets[toolchain_name]:
            content += _NATIVE_PROXY_TEMPLATE.format(
                toolchain_name = toolchain_name,
                target = target,
                compiler_repository = repository_ctx.attr.toolchain_repository_names[toolchain_name],
                exec_compatible_with = repository_ctx.attr.exec_compatible_with[toolchain_name],
                target_compatible_with = repository_ctx.attr.target_compatible_with[target],
                toolchain_type = _NATIVE_TOOLCHAIN_TYPE,
                stdlib_toolchain_type = _NATIVE_STDLIB_TOOLCHAIN_TYPE,
            )

    select = ""
    for toolchain_name in repository_ctx.attr.toolchain_names:
        values = str(repository_ctx.attr.exec_compatible_with[toolchain_name])

        content += """
config_setting(
    name = "{name}",
    constraint_values = {values},
)
""".format(name = toolchain_name, values = values)
        select += """
    ":{name}": "@{compiler_repository}//:konanc_libraries",""".format(name = toolchain_name, compiler_repository = repository_ctx.attr.toolchain_repository_names[toolchain_name])

    content += """
alias(
    name = "konanc_libraries",
    actual = select({{{select}
    }}),
    visibility = ["//visibility:public"],
)
""".format(select = select)

    repository_ctx.file("BUILD.bazel", content, executable = False)

_kt_native_toolchain_proxy = repository_rule(
    implementation = _kt_native_toolchain_proxy_impl,
    attrs = {
        "toolchain_names": attr.string_list(mandatory = True),
        "toolchain_targets": attr.string_list_dict(mandatory = True),
        "toolchain_repository_names": attr.string_dict(mandatory = True),
        "exec_compatible_with": attr.string_list_dict(mandatory = True),
        "target_compatible_with": attr.string_list_dict(mandatory = True),
    },
)

_NATIVE = """
load("@rules_kotlin_native//kotlin_native:toolchains.bzl", "kotlin_native_toolchain", "kotlin_native_stdlib_toolchain")
load("@rules_kotlin_native//kotlin_native/internal:native.bzl", "import_default_library")

java_import(
    name = "konanc_libraries",
    jars = glob([
        "konan/lib/*.jar",
    ]),
    visibility = ["//visibility:public"],
)

java_binary(
    name = "konanc",
    srcs = ["@rules_kotlin_native//tools:KonancWrapper.java"],
    main_class = "rules_kotlin_native.KonancWrapper",
    deps = [":konanc_libraries"],
)

filegroup(
    name = "dependencies",
    srcs = glob(["dependencies/**"]),
)
"""

_NATIVE_TOOLCHAIN = """
kotlin_native_toolchain(
    name = "toolchain_{kotlin_target}",
    language_version = "{language_version}",
    api_version = "{api_version}",
    konanc = ":konanc",
    kotlin_target = "{kotlin_target}",
    data_dir = ".",
    dependencies = ["konan/konan.properties", ":dependencies"] + glob([
        "konan/targets/{kotlin_target}/**",
    ]),
)

kotlin_native_stdlib_toolchain(
    name = "stdlib_toolchain_{kotlin_target}",
    default_libraries = {default_libraries},
)
"""

def _kotlin_native_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            konanc = ctx.attr.konanc,
            kotlin_target = ctx.attr.kotlin_target,
            data_dir = ctx.file.data_dir,
            dependencies = ctx.files.dependencies,
            language_version = ctx.attr.language_version,
            api_version = ctx.attr.api_version,
        ),
    ]

kotlin_native_toolchain = rule(
    implementation = _kotlin_native_toolchain_impl,
    provides = [platform_common.ToolchainInfo],
    attrs = {
        "konanc": attr.label(mandatory = True, executable = True, cfg = "exec"),
        "kotlin_target": attr.string(mandatory = True),
        "data_dir": attr.label(allow_single_file = True),
        "dependencies": attr.label_list(allow_files = True),
        "language_version": attr.string(),
        "api_version": attr.string(),
    }
)

def _kotlin_native_stdlib_toolchain_impl(ctx):
    files = depset(transitive = [library[_KtNativeStdlibInfo].files for library in ctx.attr.default_libraries])
    paths = depset(transitive = [library[_KtNativeStdlibInfo].paths for library in ctx.attr.default_libraries])

    return [
        platform_common.ToolchainInfo(
            files = files,
            paths = paths,
        ),
    ]

kotlin_native_stdlib_toolchain = rule(
    implementation = _kotlin_native_stdlib_toolchain_impl,
    provides = [platform_common.ToolchainInfo],
    attrs = {
        "default_libraries": attr.label_list(providers = [_KtNativeStdlibInfo]),
    }
)

def _get_import_string(name, path, deps):
    return """
import_default_library(
    name = "{name}",
    srcs = glob(["{path}/**"]),
    path = "{path}",
    deps = {deps},
)
""".format(name = name, path = path, deps = deps)

def _get_deps_from_manifest(repository_ctx, library_path):
    manifest = "%s/default/manifest" % library_path
    for line in repository_ctx.read(manifest).split("\n"):
        if not line.startswith("depends"):
            continue

        deps_string = line.split("=", 2)[1]
        return deps_string.split(" ")

    return []

def _kt_native_repo_impl(repository_ctx):
    version = repository_ctx.attr.version
    platform = repository_ctx.attr.platform

    data = _VERSIONS[version][platform]

    repository_ctx.download_and_extract(
        url = _URL_TEMPLATE.format(version = version, platform = platform),
        stripPrefix = _STRIP_PREFIX_TEMPLATE.format(version = version, platform = platform),
        sha256 = data["sha256"],
    )

    imports = _get_import_string(
        name = "stdlib",
        path = "klib/common/stdlib",
        deps = [],
    )

    for kotlin_target in repository_ctx.attr.kotlin_targets:
        default_libraries = [":stdlib"]

        platform_path = "klib/platform/%s" % kotlin_target

        platform_libraries = repository_ctx.path(platform_path).readdir()
        for platform_library in platform_libraries:
            platform_library_name = platform_library.basename

            default_libraries.append(":{}_{}".format(platform_library_name, kotlin_target))

            library_path = "%s/%s" % (platform_path, platform_library_name)
            deps = _get_deps_from_manifest(repository_ctx, library_path)

            def dep_name(dep):
                if dep == "stdlib":
                    return ":stdlib"

                return ":{}_{}".format(dep, kotlin_target)

            imports += _get_import_string("{}_{}".format(platform_library_name, kotlin_target), library_path, [dep_name(dep) for dep in deps])

        imports += _NATIVE_TOOLCHAIN.format(
            kotlin_target = kotlin_target,
            default_libraries = default_libraries,
            language_version = repository_ctx.attr.language_version,
            api_version = repository_ctx.attr.api_version,
        )

    repository_ctx.file(
        "BUILD.bazel",
        content = _NATIVE + imports,
        executable = False,
    )

    for dependency in data["dependencies"]:
        repository_ctx.download_and_extract(
            output = "dependencies",
            url = dependency["urls"],
            sha256 = dependency["sha256"],
        )

    content = ""
    for downloaded_dependency in repository_ctx.path("dependencies").readdir():
        content += downloaded_dependency.basename
        content += "\n"

    repository_ctx.file(
        "dependencies/.extracted",
        content = content,
        executable = False,
    )

_kt_native_repo = repository_rule(
    implementation = _kt_native_repo_impl,
    attrs = {
        "version": attr.string(mandatory = True),
        "api_version": attr.string(mandatory = True),
        "language_version": attr.string(mandatory = True),
        "platform": attr.string(mandatory = True),
        "kotlin_targets": attr.string_list(mandatory = True),
    },
)

def _get_bazel_constraint(platform_or_arch):
    if platform_or_arch == "macos":
        return "@platforms//os:macos"
    elif platform_or_arch == "ios":
        return "@platforms//os:ios"
    elif platform_or_arch == "aarch64":
        return "@platforms//cpu:arm64"
    elif platform_or_arch == "x64":
        return "@platforms//cpu:x86_64"
    else:
        fail("Unrecognized platform: " + platform_or_arch)

def _split_and_get_bazel_constraints(kotlin_platform_string):
    platforms = kotlin_platform_string.split("_")
    return [_get_bazel_constraint(platform) for platform in platforms]

_PLATFORMS = {
    "android_arm32": [
        "@platforms//os:android",
        "@platforms//cpu:armv7",
    ],
    "android_arm64": [
        "@platforms//os:android",
        "@platforms//cpu:arm64",
    ],
    "android_x64": [
        "@platforms//os:android",
        "@platforms//cpu:x86_64",
    ],
    "android_x86": [
        "@platforms//os:android",
        "@platforms//cpu:x86_32",
    ],
    "ios_arm64": [
        "@platforms//os:ios",
        "@platforms//cpu:arm64",
        "@build_bazel_apple_support//constraints:device",
    ],
    "ios_simulator_arm64": [
        "@platforms//os:ios",
        "@platforms//cpu:arm64",
        "@build_bazel_apple_support//constraints:simulator",
    ],
    "ios_x64": [
        "@platforms//os:ios",
        "@platforms//cpu:x86_64",
    ],
    "linux_arm32_hfp": [
        "@platforms//os:linux",
        # Not sure if armv7 is correct here
        "@platforms//cpu:armv7",
    ],
    "linux_arm64": [
        "@platforms//os:linux",
        "@platforms//cpu:arm64",
    ],
    "linux_x64": [
        "@platforms//os:linux",
        "@platforms//cpu:x86_64",
    ],
    "macos_arm64": [
        "@platforms//os:macos",
        "@platforms//cpu:arm64",
    ],
    "macos_x64": [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
    ],
    "mingw_x64": [
        "@platforms//os:windows",
        "@platforms//cpu:x86_64",
    ],
    "tvos_arm64": [
        "@platforms//os:tvos",
        "@platforms//cpu:arm64",
        "@build_bazel_apple_support//constraints:device",
    ],
    "tvos_simulator_arm64": [
        "@platforms//os:tvos",
        "@platforms//cpu:arm64",
        "@build_bazel_apple_support//constraints:simulator",
    ],
    "tvos_x64": [
        "@platforms//os:tvos",
        "@platforms//cpu:x86_64",
    ],
    "watchos_arm32": [
        "@platforms//os:watchos",
        "@platforms//cpu:armv7",
    ],
    "watchos_arm64": [
        "@platforms//os:watchos",
        "@platforms//cpu:arm64_32",
    ],
    "watchos_device_arm64": [
        "@platforms//os:watchos",
        "@platforms//cpu:arm64",
        "@build_bazel_apple_support//constraints:device",
    ],
    "watchos_simulator_arm64": [
        "@platforms//os:watchos",
        "@platforms//cpu:arm64",
        "@build_bazel_apple_support//constraints:simulator",
    ],
    "watchos_x64": [
        "@platforms//os:watchos",
        "@platforms//cpu:x86_64",
    ],
}

_DOWNLOAD_PLATFORM_MAPPING = {
    "linux-x86_64": "linux_x64",
    "macos-aarch64": "macos_arm64",
    "macos-x86_64": "macos_x64",
}

def kt_native_register_toolchains(
    version = None,
    language_version = None,
    api_version = None,
    native_compilers = _VERSIONS,
):
    version = version or "2.2.21"
    major_minor_version = ".".join(version.split(".", 2)[0:2])
    language_version = language_version or major_minor_version
    api_version = api_version or language_version

    toolchain_names = []
    toolchain_targets = {}
    toolchain_repository_names = {}
    target_compatible_with = {}
    exec_compatible_with = {}

    for platform, native_compiler_release in native_compilers[version].items():
        compiler_repository_name = "rules_kotlin_native_" + platform
        targets = native_compiler_release.get("targets", [_DOWNLOAD_PLATFORM_MAPPING[platform]])

        _kt_native_repo(
            name = compiler_repository_name,
            version = version,
            language_version = language_version,
            api_version = api_version,
            platform = platform,
            kotlin_targets = targets,
        )

        toolchain_name = platform
        toolchain_names.append(toolchain_name)
        toolchain_targets[toolchain_name] = targets
        toolchain_repository_names[toolchain_name] = compiler_repository_name
        exec_compatible_with[toolchain_name] = _PLATFORMS[_DOWNLOAD_PLATFORM_MAPPING[platform]]
        for target in targets:
            target_compatible_with[target] = _PLATFORMS[target]

    _kt_native_toolchain_proxy(
        name = "kotlin_native_toolchains",
        toolchain_names = toolchain_names,
        toolchain_targets = toolchain_targets,
        toolchain_repository_names = toolchain_repository_names,
        exec_compatible_with = exec_compatible_with,
        target_compatible_with = target_compatible_with,
    )
