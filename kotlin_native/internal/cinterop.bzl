load("@build_bazel_rules_swift//swift:swift.bzl", "SwiftInfo")
load("@rules_kotlin//kotlin/internal/utils:utils.bzl", _utils = "utils")
load("//kotlin_native/internal:providers.bzl", "KotlinNativeProvider")

def _kt_native_cinterop_impl(ctx):
    module_name = ctx.attr.module_name or _utils.derive_module_name(ctx)
    klib = ctx.actions.declare_file("{}.klib".format(ctx.label.name))

    args = ctx.actions.args()
    args.add("cinterop")
    args.add("-output", klib)
    args.add("-target", ctx.toolchains["//kotlin_native:toolchain_type"].kotlin_target)
    args.add("-def", ctx.file.src)
    args.add("-Xmodule-name", module_name)

    cc_info = cc_common.merge_cc_infos(cc_infos = [dep[CcInfo] for dep in ctx.attr.deps if CcInfo in dep])
    compilation_context = cc_info.compilation_context

    module_maps = []
    module_maps_depsets = []
    for dep in ctx.attr.deps:
        if SwiftInfo in dep:
            # TODO: We should only allow direct modules here but
            # apple_framework from rules_ios exposes vendored_xcframeworks as transitive modules.
            for module in dep[SwiftInfo].transitive_modules.to_list():
                if module.clang.module_map != None:
                    module_maps.append(module.clang.module_map)

        if apple_common.Objc in dep:
            module_maps_depsets.append(dep[apple_common.Objc].module_map)

    args.add("-compiler-option", "-I.")
    args.add_all(ctx.attr.copts, before_each = "-compiler-option")
    args.add_all(compilation_context.defines, before_each = "-compiler-option", format_each = "-D%s")
    args.add_all(compilation_context.includes, before_each = "-compiler-option", format_each = "-I%s")
    args.add_all(compilation_context.system_includes, before_each = "-compiler-option", format_each = "-isystem%s")
    args.add_all(compilation_context.framework_includes, before_each = "-compiler-option", format_each = "-F%s")
    args.add_all(module_maps, before_each = "-compiler-option", format_each = "-fmodule-map-file=%s")
    args.add_all(depset(transitive = module_maps_depsets), before_each = "-compiler-option", format_each = "-fmodule-map-file=%s")

    deps_klibs = depset(transitive = [dep[KotlinNativeProvider].header_klibs for dep in ctx.attr.deps if KotlinNativeProvider in dep])
    args.add_all(deps_klibs, before_each = "-library")

    ctx.actions.run(
        outputs = [klib],
        inputs = depset(
            ctx.files.src + module_maps + ctx.toolchains["//kotlin_native:toolchain_type"].dependencies,
            transitive = module_maps_depsets + [compilation_context.headers, deps_klibs],
        ),
        mnemonic = "KotlinNativeCInterop",
        progress_message = "Generating cinterop %{label}",
        env = {
            "KONAN_DATA_DIR": ctx.toolchains["//kotlin_native:toolchain_type"].data_dir.path,
        },
        arguments = [args],
        executable = ctx.toolchains["//kotlin_native:toolchain_type"].konanc.files_to_run,
    )

    # cache = _make_cache_from_klib(ctx, name = module_name, klib = klib, deps = [dep for dep in ctx.attr.deps if KotlinNativeProvider in dep])

    provider = KotlinNativeProvider(
        klib = klib,
        header_klibs = depset([klib]),
        transitive_klibs = depset([klib]),
        transitive_cc_info = cc_info,
        # transitive_cache_files = depset(cache.outputs),
        # transitive_cache_mapping = depset([cache.cache_mapping]),
        transitive_cache_files = depset([]),
        transitive_cache_mapping = depset([]),
    )

    return [
        DefaultInfo(
            files = depset([klib]),
        ),
        provider,
    ]

kt_native_cinterop = rule(
    implementation = _kt_native_cinterop_impl,
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "module_name": attr.string(),
        "deps": attr.label_list(providers = [[CcInfo], [KotlinNativeProvider]]),
        "copts": attr.string_list(),
    },
    toolchains = ["//kotlin_native:toolchain_type"],
)
