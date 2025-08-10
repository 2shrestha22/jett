import 'package:dart_mappable/dart_mappable.dart';

part 'message.mapper.dart';

@MappableClass()
class Message with MessageMappable {
  final String name;
  final bool available;

  Message({required this.name, this.available = true});

  static final fromMap = MessageMapper.fromMap;
  static final fromJson = MessageMapper.fromJson;
}
