import 'package:dart_mappable/dart_mappable.dart';

part 'message.mapper.dart';

@MappableClass()
class Message with MessageMappable {
  final String name;

  Message({required this.name});

  static final fromMap = MessageMapper.fromMap;
  static final fromJson = MessageMapper.fromJson;
}
