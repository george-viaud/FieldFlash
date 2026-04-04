class FlashProgress {
  final int bytesWritten;
  final int totalBytes;
  final String message;
  final bool isError;

  const FlashProgress({
    required this.bytesWritten,
    required this.totalBytes,
    required this.message,
    this.isError = false,
  });

  double get percentage {
    if (totalBytes == 0) return 0.0;
    final p = bytesWritten / totalBytes;
    return p > 1.0 ? 1.0 : p;
  }

  factory FlashProgress.done({required int totalBytes}) => FlashProgress(
        bytesWritten: totalBytes,
        totalBytes: totalBytes,
        message: 'Flash complete',
      );

  factory FlashProgress.error(String message) => FlashProgress(
        bytesWritten: 0,
        totalBytes: 0,
        message: message,
        isError: true,
      );
}
