import 'package:dart_mappable/dart_mappable.dart';
part 'file_info.mapper.dart';

@MappableClass()
class FileInfo with FileInfoMappable {
  final String name;
  final String? path;

  /// Content URI, android only
  final String? uri;

  FileInfo({required this.name, this.path, this.uri});
}
