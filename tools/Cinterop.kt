package rules_kotlin_native

import org.jetbrains.kotlin.cli.utilities.main as kotlinMain

fun main(args: Array<String>) {
    kotlinMain(arrayOf("cinterop") + args)
}
