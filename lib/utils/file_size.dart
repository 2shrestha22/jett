String formatFileSize(int bytes) {
  if (bytes < 1024) return "$bytes B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(2)} KB";
  if (bytes < 1024 * 1024 * 1024) {
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }
  return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
}
