// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'speedometer.dart';

class SpeedometerReadingMapper extends ClassMapperBase<SpeedometerReading> {
  SpeedometerReadingMapper._();

  static SpeedometerReadingMapper? _instance;
  static SpeedometerReadingMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SpeedometerReadingMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SpeedometerReading';

  static int _$totalBytesTransferred(SpeedometerReading v) =>
      v.totalBytesTransferred;
  static const Field<SpeedometerReading, int> _f$totalBytesTransferred = Field(
    'totalBytesTransferred',
    _$totalBytesTransferred,
  );
  static int _$elapsedMilliseconds(SpeedometerReading v) =>
      v.elapsedMilliseconds;
  static const Field<SpeedometerReading, int> _f$elapsedMilliseconds = Field(
    'elapsedMilliseconds',
    _$elapsedMilliseconds,
  );
  static int? _$fileSize(SpeedometerReading v) => v.fileSize;
  static const Field<SpeedometerReading, int> _f$fileSize = Field(
    'fileSize',
    _$fileSize,
  );
  static double _$speedBps(SpeedometerReading v) => v.speedBps;
  static const Field<SpeedometerReading, double> _f$speedBps = Field(
    'speedBps',
    _$speedBps,
  );
  static double _$avgSpeedBps(SpeedometerReading v) => v.avgSpeedBps;
  static const Field<SpeedometerReading, double> _f$avgSpeedBps = Field(
    'avgSpeedBps',
    _$avgSpeedBps,
    mode: FieldMode.member,
  );
  static double _$progress(SpeedometerReading v) => v.progress;
  static const Field<SpeedometerReading, double> _f$progress = Field(
    'progress',
    _$progress,
    mode: FieldMode.member,
  );

  @override
  final MappableFields<SpeedometerReading> fields = const {
    #totalBytesTransferred: _f$totalBytesTransferred,
    #elapsedMilliseconds: _f$elapsedMilliseconds,
    #fileSize: _f$fileSize,
    #speedBps: _f$speedBps,
    #avgSpeedBps: _f$avgSpeedBps,
    #progress: _f$progress,
  };

  static SpeedometerReading _instantiate(DecodingData data) {
    return SpeedometerReading(
      totalBytesTransferred: data.dec(_f$totalBytesTransferred),
      elapsedMilliseconds: data.dec(_f$elapsedMilliseconds),
      fileSize: data.dec(_f$fileSize),
      speedBps: data.dec(_f$speedBps),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SpeedometerReading fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SpeedometerReading>(map);
  }

  static SpeedometerReading fromJson(String json) {
    return ensureInitialized().decodeJson<SpeedometerReading>(json);
  }
}

mixin SpeedometerReadingMappable {
  String toJson() {
    return SpeedometerReadingMapper.ensureInitialized()
        .encodeJson<SpeedometerReading>(this as SpeedometerReading);
  }

  Map<String, dynamic> toMap() {
    return SpeedometerReadingMapper.ensureInitialized()
        .encodeMap<SpeedometerReading>(this as SpeedometerReading);
  }

  SpeedometerReadingCopyWith<
    SpeedometerReading,
    SpeedometerReading,
    SpeedometerReading
  >
  get copyWith =>
      _SpeedometerReadingCopyWithImpl<SpeedometerReading, SpeedometerReading>(
        this as SpeedometerReading,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SpeedometerReadingMapper.ensureInitialized().stringifyValue(
      this as SpeedometerReading,
    );
  }

  @override
  bool operator ==(Object other) {
    return SpeedometerReadingMapper.ensureInitialized().equalsValue(
      this as SpeedometerReading,
      other,
    );
  }

  @override
  int get hashCode {
    return SpeedometerReadingMapper.ensureInitialized().hashValue(
      this as SpeedometerReading,
    );
  }
}

extension SpeedometerReadingValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SpeedometerReading, $Out> {
  SpeedometerReadingCopyWith<$R, SpeedometerReading, $Out>
  get $asSpeedometerReading => $base.as(
    (v, t, t2) => _SpeedometerReadingCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class SpeedometerReadingCopyWith<
  $R,
  $In extends SpeedometerReading,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    int? totalBytesTransferred,
    int? elapsedMilliseconds,
    int? fileSize,
    double? speedBps,
  });
  SpeedometerReadingCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SpeedometerReadingCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SpeedometerReading, $Out>
    implements SpeedometerReadingCopyWith<$R, SpeedometerReading, $Out> {
  _SpeedometerReadingCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SpeedometerReading> $mapper =
      SpeedometerReadingMapper.ensureInitialized();
  @override
  $R call({
    int? totalBytesTransferred,
    int? elapsedMilliseconds,
    Object? fileSize = $none,
    double? speedBps,
  }) => $apply(
    FieldCopyWithData({
      if (totalBytesTransferred != null)
        #totalBytesTransferred: totalBytesTransferred,
      if (elapsedMilliseconds != null)
        #elapsedMilliseconds: elapsedMilliseconds,
      if (fileSize != $none) #fileSize: fileSize,
      if (speedBps != null) #speedBps: speedBps,
    }),
  );
  @override
  SpeedometerReading $make(CopyWithData data) => SpeedometerReading(
    totalBytesTransferred: data.get(
      #totalBytesTransferred,
      or: $value.totalBytesTransferred,
    ),
    elapsedMilliseconds: data.get(
      #elapsedMilliseconds,
      or: $value.elapsedMilliseconds,
    ),
    fileSize: data.get(#fileSize, or: $value.fileSize),
    speedBps: data.get(#speedBps, or: $value.speedBps),
  );

  @override
  SpeedometerReadingCopyWith<$R2, SpeedometerReading, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SpeedometerReadingCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

