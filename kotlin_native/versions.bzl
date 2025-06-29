URL_TEMPLATE = "https://github.com/JetBrains/kotlin/releases/download/v{version}/kotlin-native-prebuilt-{platform}-{version}.tar.gz"

STRIP_PREFIX_TEMPLATE = "kotlin-native-prebuilt-{platform}-{version}"

VERSIONS = {
    "1.9.23": {
        "macos-x86_64": {
            "targets": [
                "ios_x64",
                "ios_arm64",
                "ios_simulator_arm64",
                "macos_x64",
                "macos_arm64",
            ],
            "sha256": "0eed7cce2e4323b6f9c58e9e76fcd4be2534e5d324355db8921f0ff9146cdc17",
            "dependencies": [{
                "urls": ["https://download.jetbrains.com/kotlin/native/libffi-3.2.1-3-darwin-macos.tar.gz"],
                "sha256": "b83357b2d4ad4be9d5466ac3cbf12570928d84109521ab687672ec8ef47d9edc",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/apple-llvm-20200714-macos-x64-essentials.tar.gz"],
                "sha256": "1fee0603a0e66d7c7e3879748017a2950b235a796b94cdb97ffcc92baf4dd086",
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
            "sha256": "27a3560dc9b79c58420ea0015c97838f44a49380854bf26397fb1cd52d6934ec",
            "dependencies": [{
                "urls": ["https://download.jetbrains.com/kotlin/native/libffi-3.3-1-macos-arm64.tar.gz"],
                "sha256": "8ca0102ad5b626e8b1699f311ab098354a90154ea3e44951f28ebdd256862ba9",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/apple-llvm-20200714-macos-aarch64-essentials.tar.gz"],
                "sha256": "78a67740308b81ab271fa03edd77acc1164d63a4313fd37dc54fbf492069830c",
            }, {
                "urls": ["https://download.jetbrains.com/kotlin/native/lldb-4-macos.tar.gz"],
                "sha256": "069193359103d4e4a4653f236e7a963e266a4a366905e858d4a68e701f43866e",
            }],
        },
    },
    "2.0.21": {
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

