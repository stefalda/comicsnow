import 'package:comicsnow/comic/natural_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('naturalCompare', () {
    test('orders numbers numerically, not lexicographically', () {
      final names = ['page10.jpg', 'page2.jpg', 'page1.jpg'];
      names.sort(naturalCompare);

      expect(names, ['page1.jpg', 'page2.jpg', 'page10.jpg']);
    });

    test('ignores leading zeros', () {
      expect(naturalCompare('page002.jpg', 'page2.jpg'), 0);
    });

    test('is case insensitive', () {
      expect(naturalCompare('Page1.jpg', 'page1.jpg'), 0);
    });

    test('handles nested folder names', () {
      final names = ['ch1/10.png', 'ch1/2.png', 'ch1/1.png'];
      names.sort(naturalCompare);

      expect(names, ['ch1/1.png', 'ch1/2.png', 'ch1/10.png']);
    });
  });
}
