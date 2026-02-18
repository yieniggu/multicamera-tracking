class SsdpDeviceMetadata {
  final String? friendlyName;
  final String? manufacturer;
  final String? modelName;

  const SsdpDeviceMetadata({
    this.friendlyName,
    this.manufacturer,
    this.modelName,
  });
}

class SsdpParser {
  static Map<String, String> parseHeaders(String response) {
    final lines = response.split(RegExp(r'\r?\n'));
    final headers = <String, String>{};

    for (final line in lines) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim().toLowerCase();
      final value = line.substring(idx + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      headers[key] = value;
    }

    return headers;
  }

  static SsdpDeviceMetadata parseDeviceDescription(String xml) {
    String? pickTag(String tag) {
      final match = RegExp(
        '<$tag>(.*?)</$tag>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(xml);
      if (match == null) return null;
      final value = match.group(1)?.trim();
      if (value == null || value.isEmpty) return null;
      return value;
    }

    return SsdpDeviceMetadata(
      friendlyName: pickTag('friendlyName'),
      manufacturer: pickTag('manufacturer'),
      modelName: pickTag('modelName'),
    );
  }
}
