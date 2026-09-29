# ONNX Runtime is loaded reflectively through JNI: R8 must not strip or rename
# it, otherwise a *release* build crashes at runtime with a ClassNotFoundError
# the first time a model is loaded.
# See third_party/flutter_onnxruntime/VENDORED.md.
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**
