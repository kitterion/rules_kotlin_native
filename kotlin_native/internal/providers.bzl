KtNativeStdlibInfo = provider(
    fields = {
        "files": "Depset of files in extracted stdlib",
        "paths": "Depset of file objects that are roots of the library and its dependencies",
        "cache_files": "Depset of files comprising stdlib cache",
        "cache_mappings": "Depset of structs representing path to cache_path mapping",
    }
)

KotlinNativeProvider = provider(fields = [
    "klib",
    "header_klibs",
    "transitive_klibs",
    "transitive_cc_info",
    "transitive_cache_files",
    "transitive_cache_mapping",
])

KspInfo = provider(fields = [
    "id",
    "apclasspath",
    "ksp_jars",
    "options",
])
