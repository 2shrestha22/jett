// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'device.dart';

class DeviceMapper extends ClassMapperBase<Device> {
  DeviceMapper._();

  static DeviceMapper? _instance;
  static DeviceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DeviceMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Device';

  static String _$ipAddress(Device v) => v.ipAddress;
  static const Field<Device, String> _f$ipAddress = Field(
    'ipAddress',
    _$ipAddress,
  );
  static int _$port(Device v) => v.port;
  static const Field<Device, int> _f$port = Field('port', _$port);
  static String _$name(Device v) => v.name;
  static const Field<Device, String> _f$name = Field('name', _$name);

  @override
  final MappableFields<Device> fields = const {
    #ipAddress: _f$ipAddress,
    #port: _f$port,
    #name: _f$name,
  };

  static Device _instantiate(DecodingData data) {
    return Device(
      ipAddress: data.dec(_f$ipAddress),
      port: data.dec(_f$port),
      name: data.dec(_f$name),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Device fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Device>(map);
  }

  static Device fromJson(String json) {
    return ensureInitialized().decodeJson<Device>(json);
  }
}

mixin DeviceMappable {
  String toJson() {
    return DeviceMapper.ensureInitialized().encodeJson<Device>(this as Device);
  }

  Map<String, dynamic> toMap() {
    return DeviceMapper.ensureInitialized().encodeMap<Device>(this as Device);
  }

  DeviceCopyWith<Device, Device, Device> get copyWith =>
      _DeviceCopyWithImpl<Device, Device>(this as Device, $identity, $identity);
  @override
  String toString() {
    return DeviceMapper.ensureInitialized().stringifyValue(this as Device);
  }

  @override
  bool operator ==(Object other) {
    return DeviceMapper.ensureInitialized().equalsValue(this as Device, other);
  }

  @override
  int get hashCode {
    return DeviceMapper.ensureInitialized().hashValue(this as Device);
  }
}

extension DeviceValueCopy<$R, $Out> on ObjectCopyWith<$R, Device, $Out> {
  DeviceCopyWith<$R, Device, $Out> get $asDevice =>
      $base.as((v, t, t2) => _DeviceCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DeviceCopyWith<$R, $In extends Device, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? ipAddress, int? port, String? name});
  DeviceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DeviceCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Device, $Out>
    implements DeviceCopyWith<$R, Device, $Out> {
  _DeviceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Device> $mapper = DeviceMapper.ensureInitialized();
  @override
  $R call({String? ipAddress, int? port, String? name}) => $apply(
    FieldCopyWithData({
      if (ipAddress != null) #ipAddress: ipAddress,
      if (port != null) #port: port,
      if (name != null) #name: name,
    }),
  );
  @override
  Device $make(CopyWithData data) => Device(
    ipAddress: data.get(#ipAddress, or: $value.ipAddress),
    port: data.get(#port, or: $value.port),
    name: data.get(#name, or: $value.name),
  );

  @override
  DeviceCopyWith<$R2, Device, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _DeviceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

