import 'package:dart_mappable/dart_mappable.dart';

part 'message.mapper.dart';

@MappableClass()
/// Represents a message that can be sent over multicast for device presence.
class Message with MessageMappable {
  final String name;
  final bool available;

  Message({required this.name, this.available = true});

  static final fromMap = MessageMapper.fromMap;
  static final fromJson = MessageMapper.fromJson;
}
