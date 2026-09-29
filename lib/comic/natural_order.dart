/// Compares two strings so that embedded numbers are ordered numerically.
///
/// `page2.jpg` sorts before `page10.jpg`, which is what comic archives expect.
int naturalCompare(String a, String b) {
  final lowerA = a.toLowerCase();
  final lowerB = b.toLowerCase();

  var i = 0;
  var j = 0;

  while (i < lowerA.length && j < lowerB.length) {
    final charA = lowerA.codeUnitAt(i);
    final charB = lowerB.codeUnitAt(j);

    final digitA = _isDigit(charA);
    final digitB = _isDigit(charB);

    if (digitA && digitB) {
      // Skip leading zeros.
      while (i < lowerA.length && lowerA.codeUnitAt(i) == _zero) {
        i++;
      }
      while (j < lowerB.length && lowerB.codeUnitAt(j) == _zero) {
        j++;
      }

      final startA = i;
      final startB = j;
      while (i < lowerA.length && _isDigit(lowerA.codeUnitAt(i))) {
        i++;
      }
      while (j < lowerB.length && _isDigit(lowerB.codeUnitAt(j))) {
        j++;
      }

      final lengthA = i - startA;
      final lengthB = j - startB;

      if (lengthA != lengthB) {
        return lengthA.compareTo(lengthB);
      }

      final numberA = lowerA.substring(startA, i);
      final numberB = lowerB.substring(startB, j);
      final comparison = numberA.compareTo(numberB);
      if (comparison != 0) {
        return comparison;
      }

      continue;
    }

    if (charA != charB) {
      return charA.compareTo(charB);
    }

    i++;
    j++;
  }

  return (lowerA.length - i).compareTo(lowerB.length - j);
}

const int _zero = 0x30;
const int _nine = 0x39;

bool _isDigit(int codeUnit) => codeUnit >= _zero && codeUnit <= _nine;
