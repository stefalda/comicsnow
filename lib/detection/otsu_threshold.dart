/// Adaptive threshold selection with Otsu's method.
///
/// A fixed "brightness" threshold works badly on scanned comics: gutters are
/// often light grey (200-235) rather than pure white, so a hard-coded cutoff
/// classifies them as ink and panel segmentation finds no gutter at all.
/// Otsu picks the threshold that best separates the two dominant populations
/// (ink vs. background) from the image's own histogram.
library;

/// Computes Otsu's threshold from a 256-bin luminance [histogram].
///
/// Returns a value in `0..255`. Pixels `<= threshold` are considered ink.
int otsuThreshold(List<int> histogram) {
  assert(histogram.length == 256, 'histogram must have 256 bins');

  var total = 0;
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    total += histogram[i];
    sum += i * histogram[i];
  }
  if (total == 0) return 128;

  var weightBackground = 0;
  var sumBackground = 0.0;
  var bestThreshold = 128;
  var bestVariance = -1.0;

  for (var t = 0; t < 256; t++) {
    weightBackground += histogram[t];
    if (weightBackground == 0) continue;

    final weightForeground = total - weightBackground;
    if (weightForeground == 0) break;

    sumBackground += t * histogram[t];

    final meanBackground = sumBackground / weightBackground;
    final meanForeground = (sum - sumBackground) / weightForeground;
    final delta = meanBackground - meanForeground;
    final betweenClassVariance =
        weightBackground * weightForeground * delta * delta;

    if (betweenClassVariance > bestVariance) {
      bestVariance = betweenClassVariance;
      bestThreshold = t;
    }
  }

  return bestThreshold;
}
