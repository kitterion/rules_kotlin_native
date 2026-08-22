package rules_kotlin_native

import com.google.devtools.build.lib.worker.ProtoWorkerMessageProcessor
import com.google.devtools.build.lib.worker.WorkRequestHandler
import kotlinx.cinterop.ExperimentalForeignApi
import org.jetbrains.kotlin.backend.konan.env.setEnv
import org.jetbrains.kotlin.cli.bc.K2Native
import org.jetbrains.kotlin.cli.common.ExitCode
import org.jetbrains.kotlin.cli.common.messages.CompilerMessageSeverity
import org.jetbrains.kotlin.cli.common.messages.CompilerMessageSourceLocation
import org.jetbrains.kotlin.cli.common.messages.MessageCollector
import org.jetbrains.kotlin.cli.common.messages.MessageRenderer
import org.jetbrains.kotlin.config.Services
import org.jetbrains.kotlin.utils.usingNativeMemoryAllocator
import java.io.PrintWriter
import kotlin.system.exitProcess

class WriterMessageCollector(
    val writer: PrintWriter,
    val messageRenderer: MessageRenderer,
    val verbose: Boolean,
): MessageCollector {
    private var hasErrors = false

    override fun clear() {
    }

    override fun report(
        severity: CompilerMessageSeverity,
        message: String,
        location: CompilerMessageSourceLocation?
    ) {
        if (!verbose && severity in CompilerMessageSeverity.VERBOSE) {
            return
        }

        if (severity.isError) {
            hasErrors = true
        }

        writer.println(messageRenderer.render(severity, message, location))
    }

    override fun hasErrors(): Boolean {
        return hasErrors
    }
}

fun execute(args: Array<String>, errorWriter: PrintWriter): ExitCode {
    val compiler = K2Native()

    val arguments = compiler.createArguments()
    compiler.parseArguments(args, arguments)

    val messageCollector = WriterMessageCollector(
        errorWriter,
        MessageRenderer.PLAIN_RELATIVE_PATHS,
        arguments.verbose,
    )

    return compiler.exec(messageCollector, Services.EMPTY, arguments)
}

fun processRequests() {
    val callback = WorkRequestHandler.WorkRequestCallback { request, writer ->
        val args = request.argumentsList.toTypedArray()

        val exitCode = execute(args, writer)
        exitCode.code
    }
    val requestHandler = WorkRequestHandler.WorkRequestHandlerBuilder(
        callback,
        System.err,
        ProtoWorkerMessageProcessor(System.`in`, System.out),
    ).build()

    requestHandler.processRequests()
}

fun execute(args: Array<String>) {
    if ("--persistent_worker" in args) {
        processRequests()
        return
    }

    val exitCode = execute(args, PrintWriter(System.err))

    exitProcess(exitCode.code)
}

fun fixUpArguments(args: Array<String>): Array<String> {
    val cwd = System.getProperty("user.dir")
    return args + arrayOf(
        "-Xklib-relative-path-base=$cwd",
        "-Xdebug-prefix-map=$cwd=.",
    )
}

@OptIn(ExperimentalForeignApi::class)
fun main(args: Array<String>) {
    usingNativeMemoryAllocator {
        setEnv("LIBCLANG_DISABLE_CRASH_RECOVERY", "1")
        execute(fixUpArguments(args))
    }
}
