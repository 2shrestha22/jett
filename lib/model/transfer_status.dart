import 'package:anysend/model/file_info.dart';
import 'package:dart_mappable/dart_mappable.dart';
part 'transfer_status.mapper.dart';

enum TransferState { idle, waiting, inProgress, failed, completed }

@MappableClass()
class TransferStatus with TransferStatusMappable {
  final TransferState state;
  final List<FileInfo> files;

  TransferStatus({required this.state, required this.files});
}
