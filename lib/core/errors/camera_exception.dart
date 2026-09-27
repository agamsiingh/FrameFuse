import 'app_exception.dart';

/// Camera-related exceptions.
class CameraInitException extends AppException {
  const CameraInitException({
    super.message = 'Failed to initialize camera',
    super.userMessage = 'Could not start the camera. Please try again or restart the app.',
    super.cause,
  });
}

class CameraPermissionException extends AppException {
  const CameraPermissionException({
    super.message = 'Camera permission denied',
    super.userMessage = 'Camera access is required to take photos and videos. Please grant camera permission in Settings.',
    super.cause,
  });
}

class MicrophonePermissionException extends AppException {
  const MicrophonePermissionException({
    super.message = 'Microphone permission denied',
    super.userMessage = 'Microphone access is required for video audio. Please grant microphone permission in Settings.',
    super.cause,
  });
}

class CameraInUseException extends AppException {
  const CameraInUseException({
    super.message = 'Camera is in use by another app',
    super.userMessage = 'The camera is currently being used by another application. Please close the other app and try again.',
    super.cause,
  });
}

class CameraUnsupportedException extends AppException {
  final String feature;

  const CameraUnsupportedException({
    required this.feature,
    super.message = 'Camera feature not supported',
    String? userMessage,
    super.cause,
  }) : super(userMessage: userMessage ?? '$feature is not supported on this device.');
}

class EncoderException extends AppException {
  const EncoderException({
    super.message = 'Video encoder failed',
    super.userMessage = 'An error occurred while processing the video. The recording has been saved.',
    super.cause,
  });
}

class RecordingException extends AppException {
  const RecordingException({
    super.message = 'Recording failed',
    super.userMessage = 'An error occurred during recording. Please try again.',
    super.cause,
  });
}
