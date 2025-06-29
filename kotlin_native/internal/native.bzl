load("@rules_kotlin//kotlin/internal/utils:utils.bzl", _utils = "utils")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_kotlin//kotlin/internal:defs.bzl", "KtCompilerPluginInfo")
load("//kotlin_native/internal:providers.bzl", "KtNativeStdlibInfo", "KotlinNativeProvider", "KspInfo")

NATIVE_TOOLCHAIN_TYPE = "//kotlin_native:toolchain_type"
NATIVE_STDLIB_TOOLCHAIN_TYPE = "//kotlin_native:stdlib_toolchain_type"

def _kt_ksp_plugin_impl(ctx):
    return [KspInfo(
        id = "com.google.devtools.ksp.symbol-processing",
        apclasspath = ctx.attr.dep[JavaInfo].transitive_runtime_jars,
        options = {
            "withCompilation": "true",
            "incremental": "false",
            "projectBaseDir": ".",
            "classOutputDir": "_classes",
            "javaOutputDir": "_java",
            "kotlinOutputDir": "_kotlin",
            "resourceOutputDir": "_resources",
            "cachesDir": "_caches",
            "kspOutputDir": "_ksp_output",
        },
    )]

kt_ksp_plugin = rule(
    implementation = _kt_ksp_plugin_impl,
    attrs = {
        "dep": attr.label(mandatory = True, providers = [JavaInfo]),
    },
)

def _common_args(ctx, output_type):
    args = ctx.actions.args()

    toolchain = ctx.toolchains[NATIVE_TOOLCHAIN_TYPE]

    args.add("-produce", output_type)
    args.add("-target", toolchain.kotlin_target)
    args.add("-Xoverride-konan-properties=airplaneMode=true")
    args.add("-Xmulti-platform")
    args.add("-Xexpect-actual-classes")
    if toolchain.language_version:
        args.add("-language-version", toolchain.language_version)
    if toolchain.api_version:
        args.add("-api-version", toolchain.api_version)

    args.add("-kotlin-home", toolchain.data_dir.path)

    if ctx.var["COMPILATION_MODE"] == "opt":
        args.add("-opt")
    elif ctx.var["COMPILATION_MODE"] == "dbg":
        args.add("-g")
        args.add("-enable-assertions")

    args.add("-no-default-libs")
    args.add("-nostdlib")

    return args

def _format_compiler_plugin_option(option):
    return "plugin:%s:%s" % (option.id, option.value)

def _extract_srcjars(ctx, srcjars):
    directories = []

    for index, srcjar in enumerate(srcjars, start = 1):
        directory = ctx.actions.declare_directory("_%s_srcjar_%s/kotlin" % (ctx.label.name, index))

        args = ctx.actions.args()
        args.add("-q")
        args.add(srcjar)
        args.add("-d", directory.path)

        ctx.actions.run(
            outputs = [directory],
            inputs = [srcjar],
            executable = "unzip",
            arguments = [args],
        )

        directories.append(directory)

    return directories

def _import_default_library_impl(ctx):
    inputs = depset(ctx.files.srcs, transitive = [dep[KtNativeStdlibInfo].files for dep in ctx.attr.deps])

    return [KtNativeStdlibInfo(
        files = inputs,
        paths = depset([ctx.file.path], transitive = [dep[KtNativeStdlibInfo].paths for dep in ctx.attr.deps]),
    )]


import_default_library = rule(
    implementation = _import_default_library_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "path": attr.label(allow_single_file = True, mandatory = True),
        "deps": attr.label_list(providers = [KtNativeStdlibInfo]),
    },
    toolchains = [NATIVE_TOOLCHAIN_TYPE],
)

def _to_path(file):
    return file.path

def _generate_ksp_action(ctx, target, module_name, plugins, srcs, platform_srcs, libraries):
    classpath = []
    for plugin in plugins:
        if KspInfo in plugin:
            classpath.append(plugin[KspInfo].apclasspath)

    if not classpath:
        return []

    output = ctx.actions.declare_directory(ctx.label.name + "_ksp_")

    args = ctx.actions.args()
    args.add("-target", target)
    args.add("-module-name", module_name)
    args.add_joined("-source-roots", depset(srcs + platform_srcs), join_with=":")
    # args.add_joined("-common-source-roots", srcs, join_with=":")
    args.add("-project-base-dir=.")
    args.add("-output-base-dir", output.path)
    args.add("-caches-dir", "_caches")
    args.add("-class-output-dir=_classes")
    args.add("-kotlin-output-dir", output.path)
    args.add("-resource-output-dir", "_resources")

    toolchain = ctx.toolchains[NATIVE_TOOLCHAIN_TYPE]

    if not toolchain.language_version:
        fail("language_version not set in the toolchain, cannot run ksp")
    args.add("-language-version", toolchain.language_version)

    if not toolchain.api_version:
        fail("api_version not set in the toolchain, cannot run ksp")
    args.add("-api-version", toolchain.api_version)

    args.add("-incremental=false")

    args.add_joined(
        "-libraries",
        depset(transitive = [libraries, ctx.toolchains[NATIVE_STDLIB_TOOLCHAIN_TYPE].paths]),
        join_with = ":",
        map_each = _to_path,
    )

    args.add_joined(depset(transitive = classpath), join_with=":")

    ctx.actions.run(
        outputs = [output],
        inputs = depset(
            srcs + platform_srcs,
            transitive = [libraries, ctx.toolchains[NATIVE_STDLIB_TOOLCHAIN_TYPE].files] + classpath,
        ),
        mnemonic = "KspGenerate",
        progress_message = "Running ksp %{label}",
        arguments = [args],
        executable = ctx.executable._ksp_compiler,
    )

    return [output]

def _compile(
    ctx,
    output,
    output_type,
    header_output = None,
    module_name = None,
    srcs = [],
    platform_srcs = [],
    include = [],
    deps = [],
    plugins = [],
    extra_compiler_flags = [],
    extra_inputs = [],
):
    args = _common_args(ctx, output_type)

    module_name = module_name or _utils.derive_module_name(ctx)
    args.add("-module-name", module_name)

    args.add("-output", output)
    outputs = [output]

    # deps_klibs = depset(transitive = [dep[KotlinNativeProvider].transitive_klibs for dep in deps])
    deps_klibs = depset(transitive = [dep[KotlinNativeProvider].header_klibs for dep in deps])
    args.add_all(deps_klibs, before_each = "-library")

    args.add_all(include, format_each = "-Xinclude=%s")

    if header_output != None:
        args.add("-Xheader-klib-path=" + header_output.path)
        outputs.append(header_output)

    deps_from_toolchain = ctx.toolchains[NATIVE_STDLIB_TOOLCHAIN_TYPE].files
    args.add_all(ctx.toolchains[NATIVE_STDLIB_TOOLCHAIN_TYPE].paths, before_each = "-library")
    args.add("-Xpurge-user-libs")

    common_files = []
    srcjars = []

    for src in srcs:
        if src.path.endswith(".srcjar"):
            srcjars.append(src)
        else:
            common_files.append(src)

    common_files.extend(_extract_srcjars(ctx, srcjars))

    ksp_outputs = _generate_ksp_action(
        ctx = ctx,
        target = ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].kotlin_target,
        module_name = module_name,
        plugins = plugins,
        srcs = common_files,
        platform_srcs = platform_srcs,
        libraries = deps_klibs,
    )

    common_files.extend(ksp_outputs)

    args.add_all(common_files, format_each = "-Xcommon-sources=%s")
    args.add_all(common_files)
    args.add_all(platform_srcs)

    args.add_all(extra_compiler_flags)

    args.use_param_file("@%s")
    args.set_param_file_format("multiline")

    compiler_plugins_classpath = []
    for plugin in plugins:
        if KtCompilerPluginInfo in plugin:
            if plugin[KtCompilerPluginInfo].compile != True:
                fail("Only plugins running in compile phase are supported")

            args.add_all(plugin[KtCompilerPluginInfo].classpath, format_each = "-Xplugin=%s")
            compiler_plugins_classpath.append(plugin[KtCompilerPluginInfo].classpath)

            args.add_all(plugin[KtCompilerPluginInfo].options, before_each = "-P", map_each = _format_compiler_plugin_option)

    ctx.actions.run(
        outputs = outputs,
        inputs = depset(
            common_files + platform_srcs + include + extra_inputs + ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].dependencies,
            transitive = [deps_klibs, deps_from_toolchain] + compiler_plugins_classpath,
        ),
        mnemonic = "KotlinNativeCompile",
        progress_message = "Compiling Kotlin/Native module %{label}",
        env = {
            "KONAN_DATA_DIR": ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].data_dir.path,
        },
        arguments = ["konanc", args],
        executable = ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].konanc.files_to_run,
    )

    return module_name

def _kt_native_library_impl(ctx):
    klib = ctx.actions.declare_file("{}.klib".format(ctx.label.name))
    header_klib = ctx.actions.declare_file("{}.header.klib".format(ctx.label.name))
    module_name = _compile(
        ctx = ctx,
        output = klib,
        header_output = header_klib,
        output_type = "library",
        srcs = ctx.files.srcs,
        platform_srcs = ctx.files.platform_srcs,
        deps = ctx.attr.deps,
        module_name = ctx.attr.module_name,
        plugins = ctx.attr.plugins,
        extra_compiler_flags = ctx.attr.kotlinc_opts,
    )

    return [DefaultInfo(files = depset([klib])), provider]

kt_native_library = rule(
    implementation = _kt_native_library_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "platform_srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [KotlinNativeProvider]),
        "module_name": attr.string(),
        "plugins": attr.label_list(providers = [[KtCompilerPluginInfo], [KspInfo]]),
        "kotlinc_opts": attr.string_list(),
        "_ksp_compiler": attr.label(
            default = "//tools:ksp_compiler",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = [NATIVE_TOOLCHAIN_TYPE, NATIVE_STDLIB_TOOLCHAIN_TYPE],
)

def _kt_native_import_impl(ctx):
    return [KotlinNativeProvider(
        klib = ctx.file.klib,
        header_klibs = depset([ctx.file.klib], transitive = [dep[KotlinNativeProvider].header_klibs for dep in ctx.attr.deps]),
        transitive_klibs = depset([ctx.file.klib], transitive = [dep[KotlinNativeProvider].transitive_klibs for dep in ctx.attr.deps]),
        transitive_cc_info = CcInfo(),
    )]

kt_native_import = rule(
    implementation = _kt_native_import_impl,
    attrs = {
        "klib": attr.label(allow_single_file = True),
        "module_name": attr.string(),
        "deps": attr.label_list(providers = [KotlinNativeProvider]),
    },
    toolchains = [NATIVE_TOOLCHAIN_TYPE, NATIVE_STDLIB_TOOLCHAIN_TYPE],
)

def _kt_native_static_framework_impl(ctx):
    args = _common_args(ctx, "framework")

    args.add("-Xstatic-framework")

    framework_name = ctx.attr.bundle_name or ctx.label.name

    output_header = ctx.actions.declare_file("{name}/{framework_name}.framework/Headers/{framework_name}.h".format(
        name = ctx.label.name,
        framework_name = framework_name
    ))
    output_modulemap = ctx.actions.declare_file("{name}/{framework_name}.framework/Modules/module.modulemap".format(
        name = ctx.label.name,
        framework_name = framework_name
    ))
    output_binary = ctx.actions.declare_file("{name}_/{framework_name}.framework/{framework_name}".format(
        name = ctx.label.name,
        framework_name = framework_name
    ))

    args.add("-Xbinary=bundleId=" + framework_name)
    args.add("-output", output_binary.dirname)

    transitive_klibs = depset(transitive = [dep[KotlinNativeProvider].transitive_klibs for dep in ctx.attr.deps])
    args.add_all(transitive_klibs, before_each = "-library")

    direct_klibs = [dep[KotlinNativeProvider].klib for dep in ctx.attr.deps]
    args.add_all(direct_klibs, format_each = "-Xexport-library=%s")

    srcs = ctx.attr.srcs or []

    args.add_all(srcs)

    args.add("-generate-no-exit-test-runner")
    args.add("-Xkonan-data-dir=" + ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].data_dir.path)

    args.add_all(ctx.attr.kotlinc_opts)

    args.use_param_file("@%s", use_always=True)
    args.set_param_file_format("multiline")

    ctx.actions.run(
        outputs = [output_binary],
        inputs = depset(
            ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].dependencies + srcs + direct_klibs,
            transitive = [
                transitive_klibs, ctx.toolchains[NATIVE_STDLIB_TOOLCHAIN_TYPE].files,
            ],
        ),
        mnemonic = "KotlinNativeLink",
        progress_message = "Generating Kotlin/Native framework %{label}",
        env = {
            "KONAN_DATA_DIR": ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].data_dir.path,
        },
        arguments = ["konanc", args],
        executable = ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].konanc.files_to_run,
    )

    args.add("-Xomit-framework-binary")
    args.add("-output", paths.dirname(output_header.dirname))

    ctx.actions.run(
        outputs = [output_header, output_modulemap],
        inputs = depset(
            ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].dependencies + srcs + direct_klibs,
            transitive = [
                transitive_klibs, ctx.toolchains[NATIVE_STDLIB_TOOLCHAIN_TYPE].files,
            ],
        ),
        mnemonic = "KotlinNativeLinkHeaders",
        progress_message = "Generating Kotlin/Native framework headers %{label}",
        env = {
            "KONAN_DATA_DIR": ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].data_dir.path,
        },
        arguments = ["konanc", args],
        executable = ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].konanc.files_to_run,
    )

    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        static_library = output_binary,
    )

    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([
            cc_common.create_linker_input(
                owner = ctx.label,
                libraries = depset([library_to_link]),
            )
        ]),
    )

    cc_info = cc_common.merge_cc_infos(
        cc_infos = [
            CcInfo(linking_context = linking_context),
        ] + [dep[KotlinNativeProvider].transitive_cc_info for dep in ctx.attr.deps],
    )

    return [
        DefaultInfo(files = depset([output_header, output_binary, output_modulemap])),
        apple_common.new_objc_provider(),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(
                headers = depset([output_header]),
                framework_includes = depset([paths.dirname(paths.dirname(output_header.dirname))]),
            ),
            linking_context = cc_info.linking_context,
        ),
    ]

kt_native_static_framework = rule(
    implementation = _kt_native_static_framework_impl,
    attrs = {
        # When producing a framework, only the tests found within the explicit source files get run.
        "srcs": attr.label_list(allow_files = True),
        "platform_srcs": attr.label_list(allow_files = True),
        "data": attr.label_list(allow_files = True),
        "deps": attr.label_list(mandatory = True, providers = [KotlinNativeProvider]),
        "bundle_name": attr.string(),
        "kotlinc_opts": attr.string_list(),
    },
    toolchains = [NATIVE_TOOLCHAIN_TYPE, NATIVE_STDLIB_TOOLCHAIN_TYPE],
)

def _build_binary(ctx, extra_compiler_flags = []):
    # This really shouldn't have an extra extension but alas
    # https://youtrack.jetbrains.com/issue/KT-25384
    klib = ctx.actions.declare_file(ctx.label.name + ".klib")

    _compile(
        ctx = ctx,
        output = klib,
        output_type = "library",
        srcs = ctx.files.srcs,
        platform_srcs = ctx.files.platform_srcs,
        deps = ctx.attr.deps,
        plugins = ctx.attr.plugins,
        extra_compiler_flags = ctx.attr.kotlinc_opts,
    )

    cc_info = cc_common.merge_cc_infos(cc_infos = [dep[KotlinNativeProvider].transitive_cc_info for dep in ctx.attr.deps])

    libs = []
    linker_args = []
    for linker_input in cc_info.linking_context.linker_inputs.to_list():
        for library in linker_input.libraries:
            libs.append(library.static_library)
            linker_args.extend([
                "-linker-option",
                "-L" + paths.dirname(library.static_library.path),
                "-linker-option",
                "-l" + paths.basename(library.static_library.path).removeprefix("lib").removesuffix(".a"),
            ])

    binary = ctx.actions.declare_file(ctx.label.name + ".kexe")

    _compile(
        ctx = ctx,
        output = binary,
        output_type = "program",
        include = [klib],
        deps = ctx.attr.deps,
        extra_compiler_flags = extra_compiler_flags + linker_args + ctx.attr.kotlinc_opts,
        extra_inputs = libs,
    )

    return binary

def _kt_native_test_impl(ctx):
    binary = _build_binary(
        ctx,
        extra_compiler_flags = ["-generate-test-runner"],
    )

    return DefaultInfo(
        executable = binary,
    )

kt_native_test = rule(
    implementation = _kt_native_test_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "platform_srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(providers = [KotlinNativeProvider]),
        "plugins": attr.label_list(providers = [[KtCompilerPluginInfo], [KspInfo]]),
        "kotlinc_opts": attr.string_list(),
    },
    test = True,
    toolchains = [NATIVE_TOOLCHAIN_TYPE, NATIVE_STDLIB_TOOLCHAIN_TYPE],
)

def _kt_native_binary_impl(ctx):
    binary = _build_binary(
        ctx,
        extra_compiler_flags = (["-entry", ctx.attr.entry_point] if ctx.attr.entry_point else []),
    )

    return DefaultInfo(
        executable = binary,
    )


kt_native_binary = rule(
    implementation = _kt_native_binary_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "platform_srcs": attr.label_list(allow_files = True),
        "entry_point": attr.string(),
        "deps": attr.label_list(providers = [KotlinNativeProvider]),
        "plugins": attr.label_list(providers = [[KtCompilerPluginInfo], [KspInfo]]),
        "kotlinc_opts": attr.string_list(),
    },
    executable = True,
    toolchains = [NATIVE_TOOLCHAIN_TYPE, NATIVE_STDLIB_TOOLCHAIN_TYPE],
)
