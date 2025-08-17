// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'file_info.dart';

class FileInfoMapper extends ClassMapperBase<FileInfo> {
  FileInfoMapper._();

  static FileInfoMapper? _instance;
  static FileInfoMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FileInfoMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'FileInfo';

  static String _$name(FileInfo v) => v.name;
  static const Field<FileInfo, String> _f$name = Field('name', _$name);
  static String? _$path(FileInfo v) => v.path;
  static const Field<FileInfo, String> _f$path = Field(
    'path',
    _$path,
    opt: true,
  );
  static String? _$uri(FileInfo v) => v.uri;
  static const Field<FileInfo, String> _f$uri = Field('uri', _$uri, opt: true);

  @override
  final MappableFields<FileInfo> fields = const {
    #name: _f$name,
    #path: _f$path,
    #uri: _f$uri,
  };

  static FileInfo _instantiate(DecodingData data) {
    return FileInfo(
      name: data.dec(_f$name),
      path: data.dec(_f$path),
      uri: data.dec(_f$uri),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static FileInfo fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<FileInfo>(map);
  }

  static FileInfo fromJson(String json) {
    return ensureInitialized().decodeJson<FileInfo>(json);
  }
}

mixin FileInfoMappable {
  String toJson() {
    return FileInfoMapper.ensureInitialized().encodeJson<FileInfo>(
      this as FileInfo,
    );
  }

  Map<String, dynamic> toMap() {
    return FileInfoMapper.ensureInitialized().encodeMap<FileInfo>(
      this as FileInfo,
    );
  }

  FileInfoCopyWith<FileInfo, FileInfo, FileInfo> get copyWith =>
      _FileInfoCopyWithImpl<FileInfo, FileInfo>(
        this as FileInfo,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return FileInfoMapper.ensureInitialized().stringifyValue(this as FileInfo);
  }

  @override
  bool operator ==(Object other) {
    return FileInfoMapper.ensureInitialized().equalsValue(
      this as FileInfo,
      other,
    );
  }

  @override
  int get hashCode {
    return FileInfoMapper.ensureInitialized().hashValue(this as FileInfo);
  }
}

extension FileInfoValueCopy<$R, $Out> on ObjectCopyWith<$R, FileInfo, $Out> {
  FileInfoCopyWith<$R, FileInfo, $Out> get $asFileInfo =>
      $base.as((v, t, t2) => _FileInfoCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class FileInfoCopyWith<$R, $In extends FileInfo, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, String? path, String? uri});
  FileInfoCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _FileInfoCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, FileInfo, $Out>
    implements FileInfoCopyWith<$R, FileInfo, $Out> {
  _FileInfoCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<FileInfo> $mapper =
      FileInfoMapper.ensureInitialized();
  @override
  $R call({String? name, Object? path = $none, Object? uri = $none}) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (path != $none) #path: path,
      if (uri != $none) #uri: uri,
    }),
  );
  @override
  FileInfo $make(CopyWithData data) => FileInfo(
    name: data.get(#name, or: $value.name),
    path: data.get(#path, or: $value.path),
    uri: data.get(#uri, or: $value.uri),
  );

  @override
  FileInfoCopyWith<$R2, FileInfo, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _FileInfoCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

