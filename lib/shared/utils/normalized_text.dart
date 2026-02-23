String normalizeComparableText(String value) {
  final collapsedWhitespace = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return collapsedWhitespace.toLowerCase();
}
