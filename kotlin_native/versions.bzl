URL_TEMPLATE = "https://github.com/JetBrains/kotlin/releases/download/v{version}/kotlin-native-prebuilt-{platform}-{version}.tar.gz"

STRIP_PREFIX_TEMPLATE = "kotlin-native-prebuilt-{platform}-{version}"

VERSIONS = {
    "2.0.21": {
        "linux-x86_64": {
            "targets": [
                "android_arm32",
                "android_arm64",
                "android_x64",
                "android_x86",
                "linux_arm32_hfp",
                "linux_arm64",
                "linux_x64",
                "mingw_x64",
            ],
            "sha256": "2656624fae1aa2b8ba1c3609a3834b5d77c9bcfa102bff9be0620a3b5bb22295",
            "dependencies": [{
                "urls": ["https://download.jetbrains.com/kotlin/native/x86_64-unknown-linux-gnu-gcc-8.3.0-glibc-2.19-kernel-4.9-2.tar.gz"],
                "sha256": "a048397d50fb5a2bd6cc0f89d5a30e0b8ff0373ebff9c1d78ce1f1fb7f185a50",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/lldb-4-linux.tar.gz"],
                "sha256": "b1e145c859f44071f66231cfc98c8c16a480cbf47139fcd5dd2df4bf041fdfda",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/llvm-11.1.0-linux-x64-essentials.tar.gz"],
                "sha256": "e5d8d31282f1eeefff006da74f763ca18ee399782d077ccd92693b51feb17a21",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/libffi-3.2.1-2-linux-x86-64.tar.gz"],
                "sha256": "9d817bbca098a2fa0f1d5a8b9e57674c30d100bb4c6aeceff18d8acc5b9f382c",
            }],
        },
        "macos-aarch64": {
            "targets": [
                "ios_x64",
                "ios_arm64",
                "ios_simulator_arm64",
                "macos_x64",
                "macos_arm64",
            ],
            "sha256": "0b7e0028d9b13ccf7349277d028e5b5d1e0bf1ddbfd302196219bb654e419bf6",
            "dependencies": [{
                "urls": ["https://download.jetbrains.com/kotlin/native/libffi-3.3-1-macos-arm64.tar.gz"],
                "sha256": "8ca0102ad5b626e8b1699f311ab098354a90154ea3e44951f28ebdd256862ba9",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/resources/llvm/11.1.0-aarch64-macos/llvm-11.1.0-aarch64-macos-essentials-60.tar.gz"],
                "sha256": "5d4378c7df2ee6e9639a66bf55e90ea7f2ae460e1ea67dec019de5592e9ab1f0",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/lldb-4-macos.tar.gz"],
                "sha256": "069193359103d4e4a4653f236e7a963e266a4a366905e858d4a68e701f43866e",
            }],
        },
    },
    "2.1.21": {
        "linux-x86_64": {
            "targets": [
                "android_arm32",
                "android_arm64",
                "android_x64",
                "android_x86",
                "linux_arm32_hfp",
                "linux_arm64",
                "linux_x64",
                "mingw_x64",
            ],
            "sha256": "42fb88529b4039b6ac1961a137ccb1c79fc80315947f3ec31b56834c7ce20d0b",
            "dependencies": [{
                "urls": ["https://download.jetbrains.com/kotlin/native/x86_64-unknown-linux-gnu-gcc-8.3.0-glibc-2.19-kernel-4.9-2.tar.gz"],
                "sha256": "a048397d50fb5a2bd6cc0f89d5a30e0b8ff0373ebff9c1d78ce1f1fb7f185a50",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/lldb-4-linux.tar.gz"],
                "sha256": "b1e145c859f44071f66231cfc98c8c16a480cbf47139fcd5dd2df4bf041fdfda",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/resources/llvm/16.0.0-x86_64-linux/llvm-16.0.0-x86_64-linux-essentials-80.tar.gz"],
                "sha256": "0fa0a71dd142a9f64285235cd7d38053c96f1150f3331e4595b108dedbe6bcfe",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/libffi-3.2.1-2-linux-x86-64.tar.gz"],
                "sha256": "9d817bbca098a2fa0f1d5a8b9e57674c30d100bb4c6aeceff18d8acc5b9f382c",
            }],
        },
        "macos-x86_64": {
            "targets": [
                "ios_x64",
                "ios_arm64",
                "ios_simulator_arm64",
                "macos_x64",
                "macos_arm64",
            ],
            "sha256": "fc6b5979ec322be803bfac549661aaf0f8f7342aa3bd09008d471fff2757bbdf",
            "dependencies": [{
                "urls": ["https://download.jetbrains.com/kotlin/native/libffi-3.2.1-3-darwin-macos.tar.gz"],
                "sha256": "b83357b2d4ad4be9d5466ac3cbf12570928d84109521ab687672ec8ef47d9edc",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/resources/llvm/16.0.0-x86_64-macos/llvm-16.0.0-x86_64-macos-essentials-56.tar.gz"],
                "sha256": "500a8dca73996b17cc6c0c59ae8317d2a32cbda8094b15c1d20ede0b4e86c438",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/lldb-4-macos.tar.gz"],
                "sha256": "069193359103d4e4a4653f236e7a963e266a4a366905e858d4a68e701f43866e",
            }],
        },
        "macos-aarch64": {
            "targets": [
                "ios_x64",
                "ios_arm64",
                "ios_simulator_arm64",
                "macos_x64",
                "macos_arm64",
            ],
            "sha256": "8df16175b962bc4264a5c3b32cb042d91458babbd093c0f36194dc4645f5fe2e",
            "dependencies": [{
                "urls": ["https://download.jetbrains.com/kotlin/native/libffi-3.3-1-macos-arm64.tar.gz"],
                "sha256": "8ca0102ad5b626e8b1699f311ab098354a90154ea3e44951f28ebdd256862ba9",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/resources/llvm/16.0.0-aarch64-macos/llvm-16.0.0-aarch64-macos-essentials-65.tar.gz"],
                "sha256": "17ea70d51199172e8bbd295a1eb5279e3b352e2aa1e352ea01c79595175e81d2",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/lldb-4-macos.tar.gz"],
                "sha256": "069193359103d4e4a4653f236e7a963e266a4a366905e858d4a68e701f43866e",
            }],
        },
    },
}

