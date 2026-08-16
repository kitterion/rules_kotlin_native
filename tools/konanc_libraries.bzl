load("//kotlin_native/internal:native.bzl", "NATIVE_TOOLCHAIN_TYPE")

def _konanc_libraries(ctx):
    return [
        DefaultInfo(
            files = depset(ctx.toolchains[NATIVE_TOOLCHAIN_TYPE].konanc_libraries),
        ),
    ]

konanc_libraries = rule(
    implementation = _konanc_libraries,
    toolchains = [NATIVE_TOOLCHAIN_TYPE],
)
