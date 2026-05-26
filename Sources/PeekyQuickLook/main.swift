import Foundation

// App Extension 진입점. macOS가 NSExtension dict의 NSExtensionPrincipalClass(PreviewViewController)를
// 로드해 Quick Look 미리보기 요청을 처리한다.
//
// Foundation의 C 심볼 `NSExtensionMain`은 Swift overlay에 노출되지 않아 직접 링크.
@_silgen_name("NSExtensionMain")
private func _NSExtensionMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>) -> Int32

exit(_NSExtensionMain(CommandLine.argc, CommandLine.unsafeArgv))
