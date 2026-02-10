// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Typeasy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Typeasy", targets: ["Typeasy"])
    ],
    dependencies: [
        // Global Hotkeys
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
        // Speech Recognition
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.15.0"),
    ],
    targets: [
        // System library wrapper for sherpa-onnx C API
        .systemLibrary(
            name: "SherpaOnnx",
            path: "Typeasy/Libraries/sherpa-onnx-wrapper",
            pkgConfig: nil
        ),
        .executableTarget(
            name: "Typeasy",
            dependencies: [
                "HotKey",
                "WhisperKit",
                "SherpaOnnx",
            ],
            path: "Typeasy",
            exclude: ["Resources"],
            linkerSettings: [
                .unsafeFlags([
                    "-L", "/Users/andreyisakov/typeasy/Typeasy/Libraries/sherpa-onnx",
                    "-lsherpa-onnx",
                    "-lonnxruntime",
                    "-lc++"
                ])
            ]
        ),
    ]
)
