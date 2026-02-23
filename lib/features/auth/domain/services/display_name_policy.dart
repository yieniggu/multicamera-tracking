String? emailLocalPart(String? email) {
  if (email == null) return null;
  final atIdx = email.indexOf('@');
  if (atIdx <= 0) return null;
  return email.substring(0, atIdx).trim();
}

String resolveDisplayName({String? email, String? providerDisplayName}) {
  final fromEmail = emailLocalPart(email);
  if (fromEmail != null && fromEmail.isNotEmpty) return fromEmail;
  final fromProvider = providerDisplayName?.trim();
  if (fromProvider != null && fromProvider.isNotEmpty) return fromProvider;
  return "User";
}
