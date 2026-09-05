/// Practical (not fully RFC 5322) email format check, good enough to catch
/// obvious typos like a missing "@" or domain.
final _emailFormat = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
  r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
);

bool isValidEmail(String email) => _emailFormat.hasMatch(email);

/// Validates an email field's current text, returning the error message to
/// show under the field, or null if it's valid.
String? validateEmail(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '入力されていません';
  if (!isValidEmail(trimmed)) return 'メールアドレスの形式が正しくありません';
  return null;
}
