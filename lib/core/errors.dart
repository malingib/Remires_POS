/// A problem the user can fix (bad input, duplicate name, ...).
/// The message is safe to show on screen.
class ValidationException implements Exception {
  const ValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}
