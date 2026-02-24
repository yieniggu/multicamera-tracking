bool isEmailVerificationDeepLink(Uri uri) {
  if (_isVerifyEmailUri(uri)) {
    return true;
  }

  final nestedCandidates = [
    uri.queryParameters['link'],
    uri.queryParameters['deep_link_id'],
    uri.queryParameters['continueUrl'],
  ];

  for (final candidate in nestedCandidates) {
    if (candidate == null || candidate.isEmpty) continue;
    final nested = Uri.tryParse(candidate);
    if (nested == null) continue;
    if (_isVerifyEmailUri(nested)) {
      return true;
    }
  }

  return false;
}

bool _isVerifyEmailUri(Uri uri) {
  final mode = uri.queryParameters['mode']?.trim().toLowerCase();
  if (mode == 'verifyemail') return true;
  return false;
}
