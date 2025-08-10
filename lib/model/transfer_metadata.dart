class TransferMetadata {
  final String fileName;
  final int totalSize;
  final int transferredBytes;
  final double? speedBps;

  TransferMetadata({
    required this.fileName,
    required this.totalSize,
    required this.transferredBytes,
    this.speedBps,
  });
}
