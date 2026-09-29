import 'package:comicsnow/detection/otsu_threshold.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> histogramFromValues(List<int> values) {
  final histogram = List<int>.filled(256, 0);
  for (final value in values) {
    histogram[value]++;
  }
  return histogram;
}

void main() {
  group('otsuThreshold', () {
    test('separates two well-defined populations', () {
      final histogram = histogramFromValues([
        ...List.filled(500, 40), // ink
        ...List.filled(500, 230), // paper
      ]);

      final threshold = otsuThreshold(histogram);

      expect(threshold, greaterThanOrEqualTo(40));
      expect(threshold, lessThan(230));
    });

    test('adapts to darker paper', () {
      final histogram = histogramFromValues([
        ...List.filled(500, 30), // ink
        ...List.filled(500, 190), // darker, scanned paper
      ]);

      final threshold = otsuThreshold(histogram);

      expect(threshold, greaterThanOrEqualTo(30));
      expect(threshold, lessThan(190));
    });

    test('is robust on a flat image', () {
      final histogram = histogramFromValues(List.filled(1000, 128));

      // Should not throw and should return something usable.
      final threshold = otsuThreshold(histogram);
      expect(threshold, inInclusiveRange(0, 255));
    });

    test('handles an empty histogram', () {
      expect(otsuThreshold(List<int>.filled(256, 0)), 128);
    });
  });
}
