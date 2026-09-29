import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import '../domain/panel_detection.dart';
import '../domain/panel_detector.dart';
import 'yolo_postprocess.dart';

/// [PanelDetector] backed by an ONNX model through ONNX Runtime.
///
/// ONNX Runtime runs on desktop (macOS, Windows, Linux) as well as Android, so
/// this is the detector that brings a real model to the desktop. It is **not**
/// built for iOS: see `third_party/flutter_onnxruntime/VENDORED.md`.
///
/// The model must be a detection model whose output follows one of the common
/// YOLO export layouts — see [YoloOutputConfig] and [decodeYoloOutput].
///
/// Requires `flutter_onnxruntime` and macOS 14+ (the plugin's minimum).
class OnnxPanelDetector implements PanelDetector {
  OnnxPanelDetector({
    required this.modelPath,
    required this.modelVersion,
    this.inputWidth = 640,
    this.inputHeight = 640,
    this.confidenceThreshold = 0.35,
    this.iouThreshold = 0.7,
    this.hasObjectness = false,
    this.isEndToEnd = false,
    this.boxesAreNormalized,
    this.classNames,
    this.targetClasses,
    this.allowUpscale = false,
    this.padValue = 114,
    this.maxDetections = 300,
  });

  /// Asset path of the `.onnx` model.
  final String modelPath;

  @override
  final String modelVersion;

  /// Model input size. Ultralytics YOLO exports default to 640.
  final int inputWidth;
  final int inputHeight;

  final double confidenceThreshold;
  final double iouThreshold;

  /// Set for YOLOv5-style outputs (an extra objectness channel).
  final bool hasObjectness;

  /// Set for exports with NMS baked in (`[1, N, 6]`).
  final bool isEndToEnd;

  /// Overrides the automatic detection of normalized coordinates.
  final bool? boxesAreNormalized;

  final List<String>? classNames;
  final Set<String>? targetClasses;

  /// Whether to upscale images smaller than the model input.
  final bool allowUpscale;

  final double padValue;
  final int maxDetections;

  final OnnxRuntime _runtime = OnnxRuntime();

  OrtSession? _session;
  String? _inputName;
  String? _outputName;
  Future<void>? _initialization;

  @override
  bool get isInitialized => _session != null;

  @override
  Future<void> initialize() {
    final session = _session;
    if (session != null) {
      return Future.value();
    }
    return _initialization ??= _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    try {
      final session = await _runtime.createSessionFromAsset(modelPath);
      _session = session;
      _inputName = session.inputNames.isNotEmpty
          ? session.inputNames.first
          : 'images';
      _outputName = session.outputNames.isNotEmpty
          ? session.outputNames.first
          : 'output0';
    } catch (error) {
      throw PanelDetectionException(
        'Failed to load ONNX model "$modelPath"',
        error,
      );
    }
  }

  @override
  Future<List<PanelDetection>> detect({
    required Uint8List imageBytes,
    required int imageWidth,
    required int imageHeight,
  }) async {
    await initialize();
    final session = _session;
    final inputName = _inputName;
    final outputName = _outputName;
    if (session == null || inputName == null || outputName == null) {
      throw PanelDetectionException('ONNX model is not initialized');
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return const [];
    }

    final letterbox = computeLetterbox(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      allowUpscale: allowUpscale,
    );

    final tensor = buildYoloInput(
      image: decoded,
      letterbox: letterbox,
      padValue: padValue,
    );

    final input = await OrtValue.fromList(
      tensor,
      [1, 3, inputHeight, inputWidth],
    );

    final Map<String, OrtValue> outputs;
    try {
      outputs = await session.run({inputName: input});
    } finally {
      await input.dispose();
    }

    try {
      final output = outputs[outputName] ??
          (outputs.isEmpty ? null : outputs.values.first);
      if (output == null) {
        return const [];
      }

      final data = await output.asFlattenedList();
      final shape = output.shape;

      return decodeYoloOutput(
        output: data.cast<num>(),
        shape: shape,
        letterbox: letterbox,
        config: YoloOutputConfig(
          modelVersion: modelVersion,
          confidenceThreshold: confidenceThreshold,
          iouThreshold: iouThreshold,
          maxDetections: maxDetections,
          hasObjectness: hasObjectness,
          isEndToEnd: isEndToEnd,
          boxesAreNormalized: boxesAreNormalized,
          classNames: classNames,
          targetClasses: targetClasses,
        ),
      );
    } finally {
      for (final value in outputs.values) {
        await value.dispose();
      }
    }
  }

  @override
  Future<void> dispose() async {
    final session = _session;
    _session = null;
    await session?.close();
  }
}
