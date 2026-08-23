package rules_kotlin_native

import com.google.devtools.build.lib.worker.ProtoWorkerMessageProcessor
import com.google.devtools.build.lib.worker.WorkRequestHandler
import com.google.devtools.ksp.impl.KotlinSymbolProcessing
import com.google.devtools.ksp.processing.KSPLogger
import com.google.devtools.ksp.processing.KSPNativeConfig
import com.google.devtools.ksp.processing.SymbolProcessorProvider
import com.google.devtools.ksp.processing.kspNativeArgParser
import com.google.devtools.ksp.symbol.FileLocation
import com.google.devtools.ksp.symbol.KSNode
import com.google.devtools.ksp.symbol.NonExistLocation
import java.io.Closeable
import java.io.File
import java.io.PrintWriter
import java.lang.System
import java.net.URLClassLoader
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.security.DigestInputStream
import java.security.MessageDigest
import java.util.ServiceLoader
import java.util.concurrent.ConcurrentHashMap
import kotlin.io.path.ExperimentalPathApi
import kotlin.io.path.createTempDirectory
import kotlin.io.path.deleteRecursively
import kotlin.system.exitProcess

class KspLogger(val writer: PrintWriter, val baseDir: File): KSPLogger {
    override fun logging(message: String, symbol: KSNode?) {
        printWithTag("note", message, symbol)
    }

    override fun info(message: String, symbol: KSNode?) {
        printWithTag("info", message, symbol)
    }

    override fun warn(message: String, symbol: KSNode?) {
        printWithTag("warning", message, symbol)
    }

    override fun error(message: String, symbol: KSNode?) {
        printWithTag("error", message, symbol)
    }

    override fun exception(e: Throwable) {
        writer.println("error: $e")
        writer.flush()
    }

    private fun printWithTag(tag: String, message: String, symbol: KSNode?) {
        writer.println(renderMessage(tag, message, symbol))
        writer.flush()
    }

    private fun renderMessage(tag: String, message: String, symbol: KSNode?): String {
        return when (val location = symbol?.location) {
            is FileLocation -> {
                val file = File(location.filePath)
                val filepath = if (file.startsWith(baseDir)) {
                    file.toRelativeString(baseDir)
                } else {
                    location.filePath
                }
                "$filepath:${location.lineNumber}: $tag: $message"
            }
            is NonExistLocation, null -> {
                "$tag: " + baseDirRegex.replace(message, "")
            }
        }
    }

    private val baseDirRegex = Regex("^$baseDir/", RegexOption.MULTILINE)
}

// This mirrors the rules_kotlin logic for class loader caching.
// See https://github.com/bazel-contrib/rules_kotlin/blob/3bc687d029322382396b7198a9e7f1cf92d11f0f/src/main/kotlin/io/bazel/kotlin/builder/tasks/jvm/Ksp2Task.kt#L92
class ClassLoaderCache {
    private val cache = ConcurrentHashMap<String, CacheEntry>()

    data class CacheEntry(
        val classLoader: URLClassLoader,
        val fingerprint: String,
    )

    fun get(classpath: List<String>): ClassLoader {
        val sortedClasspath = classpath.sorted()
        val cacheKey = sortedClasspath.joinToString(File.pathSeparator)
        val fingerprint = fingerprintOf(sortedClasspath)
        return cache.compute(cacheKey) { _, existing ->
            if (existing != null && existing.fingerprint == fingerprint) {
                return@compute existing
            }
            if (existing != null) {
                runCatching { existing.classLoader.close() }
            }
            CacheEntry(
                URLClassLoader(
                    classpath.map { File(it).toURI().toURL() }.toTypedArray(),
                    ClassLoader.getSystemClassLoader(),
                ),
                fingerprint,
            )
        }!!.classLoader
    }

    fun fingerprintOf(classpath: List<String>): String {
        val digest = MessageDigest.getInstance("SHA-256")
        for (path in classpath) {
            val file = File(path)
            digest.update(path.toByteArray(StandardCharsets.UTF_8))
            digest.update(file.length().toString().toByteArray(StandardCharsets.UTF_8))
            DigestInputStream(Files.newInputStream(file.toPath()), digest).use { it.readAllBytes() }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}

fun getCwd(): File {
    val cwd = System.getProperty("user.dir")
    return File(cwd)
}

fun sanitizeKspConfig(config: KSPNativeConfig, tempDirectory: TempDirectory): KSPNativeConfig {
    fun create(name: String): File {
        val child = tempDirectory.dir.resolve(name)
        Files.createDirectory(child)
        return child.toFile()
    }

    return KSPNativeConfig(
        targetName = config.targetName,
        moduleName = config.moduleName,
        sourceRoots = config.sourceRoots,
        commonSourceRoots = config.commonSourceRoots,
        libraries = config.libraries,
        friends = config.friends,
        processorOptions = config.processorOptions,
        projectBaseDir = config.projectBaseDir,
        outputBaseDir = config.outputBaseDir,
        cachesDir = create("caches"),
        classOutputDir = create("classes"),
        kotlinOutputDir = config.kotlinOutputDir,
        resourceOutputDir = create("resources"),
        incremental = config.incremental,
        incrementalLog = config.incrementalLog,
        modifiedSources = config.modifiedSources,
        removedSources = config.removedSources,
        changedClasses = config.changedClasses,
        languageVersion = config.languageVersion,
        apiVersion = config.apiVersion,
        allWarningsAsErrors = config.allWarningsAsErrors,
        mapAnnotationArgumentsInJava = config.mapAnnotationArgumentsInJava,
        experimentalPsiResolution = config.experimentalPsiResolution,
    )
}

fun execute(args: Array<String>, logger: KspLogger, classLoaderCache: ClassLoaderCache): KotlinSymbolProcessing.ExitCode {
    val (config, classpath) = kspNativeArgParser(args)
    val processorClassloader = classLoaderCache.get(classpath)

    @Suppress("UNCHECKED_CAST")
    val processorProviders = ServiceLoader
        .load(
            processorClassloader.loadClass("com.google.devtools.ksp.processing.SymbolProcessorProvider"),
            processorClassloader
        )
        .toList() as List<SymbolProcessorProvider>

    val tempDir = TempDirectory()
    val sanitizedConfig = sanitizeKspConfig(config, tempDir)
    return tempDir.use {
        KotlinSymbolProcessing(sanitizedConfig, processorProviders, logger).execute()
    }
}

class TempDirectory: Closeable {
    val dir = createTempDirectory()

    @OptIn(ExperimentalPathApi::class)
    override fun close() {
        dir.deleteRecursively()
    }
}

fun processRequests() {
    val cwd = getCwd()
    val classLoaderCache = ClassLoaderCache()
    val callback = WorkRequestHandler.WorkRequestCallback { request, writer ->
        val args = request.argumentsList.toTypedArray()

        val logger = KspLogger(writer, cwd)
        val exitCode = execute(args, logger, classLoaderCache)
        exitCode.code
    }
    val requestHandler = WorkRequestHandler.WorkRequestHandlerBuilder(
        callback,
        System.err,
        ProtoWorkerMessageProcessor(System.`in`, System.out),
    ).build()

    requestHandler.processRequests()
}

fun main(args: Array<String>) {
    if ("--persistent_worker" in args) {
        processRequests()
        return
    }

    val exitCode = execute(
        args,
        KspLogger(
            PrintWriter(System.err),
            getCwd(),
        ),
        ClassLoaderCache(),
    )

    exitProcess(exitCode.code)
}
