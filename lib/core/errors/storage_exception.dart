import 'app_exception.dart';

/// Storage-related exceptions.
class StoragePermissionException extends AppException {
  const StoragePermissionException({
    super.message = 'Storage permission denied',
    super.userMessage = 'Storage access is required to save your photos and videos. Please grant permission in Settings.',
    super.cause,
  });
}

class InsufficientStorageException extends AppException {
  const InsufficientStorageException({
    super.message = 'Insufficient storage',
    super.userMessage = 'Not enough storage space to save media. Please free up space and try again.',
    super.cause,
  });
}

class StorageWriteException extends AppException {
  const StorageWriteException({
    super.message = 'Failed to write file',
    super.userMessage = 'Could not save the file. Please check storage availability and try again.',
    super.cause,
  });
}

class StorageReadException extends AppException {
  const StorageReadException({
    super.message = 'Failed to read file',
    super.userMessage = 'Could not load the file. It may have been moved or deleted.',
    super.cause,
  });
}
