// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'transfer_status.dart';

class TransferStatusMapper extends ClassMapperBase<TransferStatus> {
  TransferStatusMapper._();

  static TransferStatusMapper? _instance;
  static TransferStatusMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TransferStatusMapper._());
      FileInfoMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'TransferStatus';

  static TransferState _$state(TransferStatus v) => v.state;
  static const Field<TransferStatus, TransferState> _f$state = Field(
    'state',
    _$state,
  );
  static List<FileInfo> _$files(TransferStatus v) => v.files;
  static const Field<TransferStatus, List<FileInfo>> _f$files = Field(
    'files',
    _$files,
  );

  @override
  final MappableFields<TransferStatus> fields = const {
    #state: _f$state,
    #files: _f$files,
  };

  static TransferStatus _instantiate(DecodingData data) {
    return TransferStatus(state: data.dec(_f$state), files: data.dec(_f$files));
  }

  @override
  final Function instantiate = _instantiate;

  static TransferStatus fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<TransferStatus>(map);
  }

  static TransferStatus fromJson(String json) {
    return ensureInitialized().decodeJson<TransferStatus>(json);
  }
}

mixin TransferStatusMappable {
  String toJson() {
    return TransferStatusMapper.ensureInitialized().encodeJson<TransferStatus>(
      this as TransferStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return TransferStatusMapper.ensureInitialized().encodeMap<TransferStatus>(
      this as TransferStatus,
    );
  }

  TransferStatusCopyWith<TransferStatus, TransferStatus, TransferStatus>
  get copyWith => _TransferStatusCopyWithImpl<TransferStatus, TransferStatus>(
    this as TransferStatus,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return TransferStatusMapper.ensureInitialized().stringifyValue(
      this as TransferStatus,
    );
  }

  @override
  bool operator ==(Object other) {
    return TransferStatusMapper.ensureInitialized().equalsValue(
      this as TransferStatus,
      other,
    );
  }

  @override
  int get hashCode {
    return TransferStatusMapper.ensureInitialized().hashValue(
      this as TransferStatus,
    );
  }
}

extension TransferStatusValueCopy<$R, $Out>
    on ObjectCopyWith<$R, TransferStatus, $Out> {
  TransferStatusCopyWith<$R, TransferStatus, $Out> get $asTransferStatus =>
      $base.as((v, t, t2) => _TransferStatusCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class TransferStatusCopyWith<$R, $In extends TransferStatus, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, FileInfo, FileInfoCopyWith<$R, FileInfo, FileInfo>>
  get files;
  $R call({TransferState? state, List<FileInfo>? files});
  TransferStatusCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _TransferStatusCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, TransferStatus, $Out>
    implements TransferStatusCopyWith<$R, TransferStatus, $Out> {
  _TransferStatusCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<TransferStatus> $mapper =
      TransferStatusMapper.ensureInitialized();
  @override
  ListCopyWith<$R, FileInfo, FileInfoCopyWith<$R, FileInfo, FileInfo>>
  get files => ListCopyWith(
    $value.files,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(files: v),
  );
  @override
  $R call({TransferState? state, List<FileInfo>? files}) => $apply(
    FieldCopyWithData({
      if (state != null) #state: state,
      if (files != null) #files: files,
    }),
  );
  @override
  TransferStatus $make(CopyWithData data) => TransferStatus(
    state: data.get(#state, or: $value.state),
    files: data.get(#files, or: $value.files),
  );

  @override
  TransferStatusCopyWith<$R2, TransferStatus, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _TransferStatusCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

