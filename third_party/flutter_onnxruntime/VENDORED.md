# Vendored copy of flutter_onnxruntime 1.8.5

Source: https://pub.dev/packages/flutter_onnxruntime/versions/1.8.5

## Local modification

`ios/flutter_onnxruntime/Package.swift` has been **removed**, so that on iOS the
plugin integrates through CocoaPods (`flutter_onnxruntime.podspec`, minimum
iOS 16.0) instead of Swift Package Manager.

Reason: Flutter generates `FlutterGeneratedPluginSwiftPackage/Package.swift`
with a hard-coded `.iOS("15.0")` platform and never raises it (verified: the
deployment target is 16.0 and `xcodebuild -showBuildSettings` reports 16.0, but
the generated manifest stays at 15.0). Xcode then fails with:

```
Target Integrity: The package product 'flutter-onnxruntime-product' requires
minimum platform version 16.0 for the iOS platform, but this target supports 15.0
```

With the iOS Swift Package gone, iOS uses the podspec (iOS 16.0, matching the
Podfile) and links `onnxruntime-objc`, which requires static frameworks:
`use_frameworks! :linkage => :static` in `ios/Podfile`.

macOS keeps `macos/flutter_onnxruntime/Package.swift` and therefore keeps using
Swift Package Manager, which already worked.

Re-check this when upgrading Flutter or the plugin: if Flutter starts raising
the generated package's platform, the iOS manifest can be restored and the pin
dropped.
