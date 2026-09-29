// Prepares a square, opaque app-icon source from `assets/icon/icon.png`.
//
// The source artwork is a rounded square with transparent corners, slightly
// non-square (610x588). Platform icon sets need a square, and iOS rejects
// icons with an alpha channel, so this script:
//
//   1. trims the fully transparent margins;
//   2. cover-scales to a square (the rounded corners fall just outside);
//   3. paints a background gradient sampled from the artwork's own left/right
//      edges, so the (now square) corners blend seamlessly;
//   4. composites the artwork on top and writes `assets/icon/icon_source.png`.
//
// Run with: dart run tool/generate_icon.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _sourcePath = 'assets/icon/icon.png';
const _outputPath = 'assets/icon/icon_source.png';
const _size = 1024;

void main() {
  final file = File(_sourcePath);
  if (!file.existsSync()) {
    stderr.writeln('Source icon not found: $_sourcePath');
    exitCode = 1;
    return;
  }

  final decoded = img.decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode $_sourcePath');
    exitCode = 1;
    return;
  }

  final trimmed = _trimTransparent(decoded);
  final squared = _coverResize(trimmed, _size);
  final canvas = _backgroundFromEdges(squared);
  img.compositeImage(canvas, squared);

  File(_outputPath).writeAsBytesSync(img.encodePng(canvas, level: 6));
  stdout.writeln('Wrote $_outputPath (${_size}x$_size) from '
      '${decoded.width}x${decoded.height}');
}

/// Bounding box of the pixels that are not (almost) fully transparent.
img.Image _trimTransparent(img.Image source) {
  var minX = source.width;
  var minY = source.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (source.getPixel(x, y).a > 8) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < 0) return source;

  return img.copyCrop(
    source,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

/// Scales so the shorter side fills [size], then center-crops to a square.
img.Image _coverResize(img.Image source, int size) {
  final scale = math.max(size / source.width, size / source.height);
  final width = (source.width * scale).round();
  final height = (source.height * scale).round();

  final resized = img.copyResize(
    source,
    width: width,
    height: height,
    interpolation: img.Interpolation.cubic,
  );

  return img.copyCrop(
    resized,
    x: ((width - size) / 2).round(),
    y: ((height - size) / 2).round(),
    width: size,
    height: size,
  );
}

/// Fills a square canvas with a per-row gradient taken from the artwork's own
/// edges, so the transparent corners get the colour the artwork would have had
/// there. The sample is taken slightly inside the edge, to skip the artwork's
/// own outline.
img.Image _backgroundFromEdges(img.Image artwork) {
  final canvas = img.Image(
    width: artwork.width,
    height: artwork.height,
    numChannels: 4,
  );

  // Skip the rounded border of the artwork when sampling.
  final inset = math.max(4, (artwork.width * 0.012).round());

  var lastLeft = (r: 27, g: 95, b: 190);
  var lastRight = lastLeft;

  for (var y = 0; y < artwork.height; y++) {
    int? leftIndex;
    int? rightIndex;

    for (var x = 0; x < artwork.width; x++) {
      if (artwork.getPixel(x, y).a > 8) {
        leftIndex = x;
        break;
      }
    }
    for (var x = artwork.width - 1; x >= 0; x--) {
      if (artwork.getPixel(x, y).a > 8) {
        rightIndex = x;
        break;
      }
    }

    if (leftIndex != null && rightIndex != null) {
      final left = artwork.getPixel(
        math.min(leftIndex + inset, artwork.width - 1),
        y,
      );
      final right = artwork.getPixel(
        math.max(rightIndex - inset, 0),
        y,
      );
      lastLeft = (r: left.r.round(), g: left.g.round(), b: left.b.round());
      lastRight = (r: right.r.round(), g: right.g.round(), b: right.b.round());

      for (var x = 0; x <= leftIndex; x++) {
        canvas.setPixelRgba(
          x,
          y,
          lastLeft.r,
          lastLeft.g,
          lastLeft.b,
          255,
        );
      }
      for (var x = rightIndex; x < artwork.width; x++) {
        canvas.setPixelRgba(
          x,
          y,
          lastRight.r,
          lastRight.g,
          lastRight.b,
          255,
        );
      }
    }
  }

  return canvas;
}
