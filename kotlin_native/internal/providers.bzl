KtNativeStdlibInfo = provider(
    fields = {
        "files": "Depset of files in extracted stdlib",
        "paths": "Depset of file objects that are roots of the library and its dependencies",
    }
)

KotlinNativeProvider = provider(fields = [
    "klib",
    "header_klibs",
    "transitive_klibs",
    "transitive_cc_info",
])

KspInfo = provider(fields = [
    "id",
    "apclasspath",
    "ksp_jars",
    "options",
])
