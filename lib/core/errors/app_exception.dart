/// Base exception hierarchy for FrameFuse.
///
/// All app-specific exceptions extend [AppException] so they can be caught
/// uniformly at the UI boundary and translated to user-facing messages.
abstract class AppException implements Exception {
  final String message;
  final String? userMessage;
  final Object? cause;

  const AppException({
    required this.message,
    this.userMessage,
    this.cause,
  });

  /// Returns the user-facing message, falling back to the technical [message].
  String get displayMessage => userMessage ?? message;

  @override
  String toString() => '$runtimeType: $message';
}
