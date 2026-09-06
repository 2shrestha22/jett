// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'message.dart';

class MessageMapper extends ClassMapperBase<Message> {
  MessageMapper._();

  static MessageMapper? _instance;
  static MessageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MessageMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Message';

  static String _$name(Message v) => v.name;
  static const Field<Message, String> _f$name = Field('name', _$name);
  static bool _$available(Message v) => v.available;
  static const Field<Message, bool> _f$available = Field(
    'available',
    _$available,
    opt: true,
    def: true,
  );
  static int? _$protocolVersion(Message v) => v.protocolVersion;
  static const Field<Message, int> _f$protocolVersion = Field(
    'protocolVersion',
    _$protocolVersion,
    opt: true,
  );

  @override
  final MappableFields<Message> fields = const {
    #name: _f$name,
    #available: _f$available,
    #protocolVersion: _f$protocolVersion,
  };

  static Message _instantiate(DecodingData data) {
    return Message(
      name: data.dec(_f$name),
      available: data.dec(_f$available),
      protocolVersion: data.dec(_f$protocolVersion),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Message fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Message>(map);
  }

  static Message fromJson(String json) {
    return ensureInitialized().decodeJson<Message>(json);
  }
}

mixin MessageMappable {
  String toJson() {
    return MessageMapper.ensureInitialized().encodeJson<Message>(
      this as Message,
    );
  }

  Map<String, dynamic> toMap() {
    return MessageMapper.ensureInitialized().encodeMap<Message>(
      this as Message,
    );
  }

  MessageCopyWith<Message, Message, Message> get copyWith =>
      _MessageCopyWithImpl<Message, Message>(
        this as Message,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return MessageMapper.ensureInitialized().stringifyValue(this as Message);
  }

  @override
  bool operator ==(Object other) {
    return MessageMapper.ensureInitialized().equalsValue(
      this as Message,
      other,
    );
  }

  @override
  int get hashCode {
    return MessageMapper.ensureInitialized().hashValue(this as Message);
  }
}

extension MessageValueCopy<$R, $Out> on ObjectCopyWith<$R, Message, $Out> {
  MessageCopyWith<$R, Message, $Out> get $asMessage =>
      $base.as((v, t, t2) => _MessageCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class MessageCopyWith<$R, $In extends Message, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, bool? available, int? protocolVersion});
  MessageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _MessageCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Message, $Out>
    implements MessageCopyWith<$R, Message, $Out> {
  _MessageCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Message> $mapper =
      MessageMapper.ensureInitialized();
  @override
  $R call({String? name, bool? available, Object? protocolVersion = $none}) =>
      $apply(
        FieldCopyWithData({
          if (name != null) #name: name,
          if (available != null) #available: available,
          if (protocolVersion != $none) #protocolVersion: protocolVersion,
        }),
      );
  @override
  Message $make(CopyWithData data) => Message(
    name: data.get(#name, or: $value.name),
    available: data.get(#available, or: $value.available),
    protocolVersion: data.get(#protocolVersion, or: $value.protocolVersion),
  );

  @override
  MessageCopyWith<$R2, Message, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _MessageCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

