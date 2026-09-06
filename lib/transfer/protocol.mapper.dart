// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'protocol.dart';

class OfferedFileMapper extends ClassMapperBase<OfferedFile> {
  OfferedFileMapper._();

  static OfferedFileMapper? _instance;
  static OfferedFileMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = OfferedFileMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'OfferedFile';

  static String _$name(OfferedFile v) => v.name;
  static const Field<OfferedFile, String> _f$name = Field('name', _$name);
  static int _$size(OfferedFile v) => v.size;
  static const Field<OfferedFile, int> _f$size = Field('size', _$size);
  static String? _$mimeType(OfferedFile v) => v.mimeType;
  static const Field<OfferedFile, String> _f$mimeType = Field(
    'mimeType',
    _$mimeType,
    opt: true,
  );

  @override
  final MappableFields<OfferedFile> fields = const {
    #name: _f$name,
    #size: _f$size,
    #mimeType: _f$mimeType,
  };

  static OfferedFile _instantiate(DecodingData data) {
    return OfferedFile(
      name: data.dec(_f$name),
      size: data.dec(_f$size),
      mimeType: data.dec(_f$mimeType),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static OfferedFile fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<OfferedFile>(map);
  }

  static OfferedFile fromJson(String json) {
    return ensureInitialized().decodeJson<OfferedFile>(json);
  }
}

mixin OfferedFileMappable {
  String toJson() {
    return OfferedFileMapper.ensureInitialized().encodeJson<OfferedFile>(
      this as OfferedFile,
    );
  }

  Map<String, dynamic> toMap() {
    return OfferedFileMapper.ensureInitialized().encodeMap<OfferedFile>(
      this as OfferedFile,
    );
  }

  OfferedFileCopyWith<OfferedFile, OfferedFile, OfferedFile> get copyWith =>
      _OfferedFileCopyWithImpl<OfferedFile, OfferedFile>(
        this as OfferedFile,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return OfferedFileMapper.ensureInitialized().stringifyValue(
      this as OfferedFile,
    );
  }

  @override
  bool operator ==(Object other) {
    return OfferedFileMapper.ensureInitialized().equalsValue(
      this as OfferedFile,
      other,
    );
  }

  @override
  int get hashCode {
    return OfferedFileMapper.ensureInitialized().hashValue(this as OfferedFile);
  }
}

extension OfferedFileValueCopy<$R, $Out>
    on ObjectCopyWith<$R, OfferedFile, $Out> {
  OfferedFileCopyWith<$R, OfferedFile, $Out> get $asOfferedFile =>
      $base.as((v, t, t2) => _OfferedFileCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class OfferedFileCopyWith<$R, $In extends OfferedFile, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, int? size, String? mimeType});
  OfferedFileCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _OfferedFileCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, OfferedFile, $Out>
    implements OfferedFileCopyWith<$R, OfferedFile, $Out> {
  _OfferedFileCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<OfferedFile> $mapper =
      OfferedFileMapper.ensureInitialized();
  @override
  $R call({String? name, int? size, Object? mimeType = $none}) => $apply(
    FieldCopyWithData({
      if (name != null) #name: name,
      if (size != null) #size: size,
      if (mimeType != $none) #mimeType: mimeType,
    }),
  );
  @override
  OfferedFile $make(CopyWithData data) => OfferedFile(
    name: data.get(#name, or: $value.name),
    size: data.get(#size, or: $value.size),
    mimeType: data.get(#mimeType, or: $value.mimeType),
  );

  @override
  OfferedFileCopyWith<$R2, OfferedFile, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _OfferedFileCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ControlMessageMapper extends ClassMapperBase<ControlMessage> {
  ControlMessageMapper._();

  static ControlMessageMapper? _instance;
  static ControlMessageMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ControlMessageMapper._());
      RequestFrameMapper.ensureInitialized();
      AcceptedFrameMapper.ensureInitialized();
      DeclinedFrameMapper.ensureInitialized();
      ProgressFrameMapper.ensureInitialized();
      CompletedFrameMapper.ensureInitialized();
      FailedFrameMapper.ensureInitialized();
      CancelFrameMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ControlMessage';

  static String _$sessionId(ControlMessage v) => v.sessionId;
  static const Field<ControlMessage, String> _f$sessionId = Field(
    'sessionId',
    _$sessionId,
  );

  @override
  final MappableFields<ControlMessage> fields = const {
    #sessionId: _f$sessionId,
  };

  static ControlMessage _instantiate(DecodingData data) {
    throw MapperException.missingSubclass(
      'ControlMessage',
      'type',
      '${data.value['type']}',
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ControlMessage fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ControlMessage>(map);
  }

  static ControlMessage fromJson(String json) {
    return ensureInitialized().decodeJson<ControlMessage>(json);
  }
}

mixin ControlMessageMappable {
  String toJson();
  Map<String, dynamic> toMap();
  ControlMessageCopyWith<ControlMessage, ControlMessage, ControlMessage>
  get copyWith;
}

abstract class ControlMessageCopyWith<$R, $In extends ControlMessage, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? sessionId});
  ControlMessageCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class RequestFrameMapper extends SubClassMapperBase<RequestFrame> {
  RequestFrameMapper._();

  static RequestFrameMapper? _instance;
  static RequestFrameMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = RequestFrameMapper._());
      ControlMessageMapper.ensureInitialized().addSubMapper(_instance!);
      OfferedFileMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'RequestFrame';

  static String _$sessionId(RequestFrame v) => v.sessionId;
  static const Field<RequestFrame, String> _f$sessionId = Field(
    'sessionId',
    _$sessionId,
  );
  static String _$senderName(RequestFrame v) => v.senderName;
  static const Field<RequestFrame, String> _f$senderName = Field(
    'senderName',
    _$senderName,
  );
  static List<OfferedFile> _$files(RequestFrame v) => v.files;
  static const Field<RequestFrame, List<OfferedFile>> _f$files = Field(
    'files',
    _$files,
  );
  static int _$totalSize(RequestFrame v) => v.totalSize;
  static const Field<RequestFrame, int> _f$totalSize = Field(
    'totalSize',
    _$totalSize,
  );
  static bool _$requestVerification(RequestFrame v) => v.requestVerification;
  static const Field<RequestFrame, bool> _f$requestVerification = Field(
    'requestVerification',
    _$requestVerification,
    opt: true,
    def: false,
  );
  static int _$protocolVersion(RequestFrame v) => v.protocolVersion;
  static const Field<RequestFrame, int> _f$protocolVersion = Field(
    'protocolVersion',
    _$protocolVersion,
    opt: true,
    def: kProtocolVersion,
  );

  @override
  final MappableFields<RequestFrame> fields = const {
    #sessionId: _f$sessionId,
    #senderName: _f$senderName,
    #files: _f$files,
    #totalSize: _f$totalSize,
    #requestVerification: _f$requestVerification,
    #protocolVersion: _f$protocolVersion,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'request';
  @override
  late final ClassMapperBase superMapper =
      ControlMessageMapper.ensureInitialized();

  static RequestFrame _instantiate(DecodingData data) {
    return RequestFrame(
      sessionId: data.dec(_f$sessionId),
      senderName: data.dec(_f$senderName),
      files: data.dec(_f$files),
      totalSize: data.dec(_f$totalSize),
      requestVerification: data.dec(_f$requestVerification),
      protocolVersion: data.dec(_f$protocolVersion),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static RequestFrame fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<RequestFrame>(map);
  }

  static RequestFrame fromJson(String json) {
    return ensureInitialized().decodeJson<RequestFrame>(json);
  }
}

mixin RequestFrameMappable {
  String toJson() {
    return RequestFrameMapper.ensureInitialized().encodeJson<RequestFrame>(
      this as RequestFrame,
    );
  }

  Map<String, dynamic> toMap() {
    return RequestFrameMapper.ensureInitialized().encodeMap<RequestFrame>(
      this as RequestFrame,
    );
  }

  RequestFrameCopyWith<RequestFrame, RequestFrame, RequestFrame> get copyWith =>
      _RequestFrameCopyWithImpl<RequestFrame, RequestFrame>(
        this as RequestFrame,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return RequestFrameMapper.ensureInitialized().stringifyValue(
      this as RequestFrame,
    );
  }

  @override
  bool operator ==(Object other) {
    return RequestFrameMapper.ensureInitialized().equalsValue(
      this as RequestFrame,
      other,
    );
  }

  @override
  int get hashCode {
    return RequestFrameMapper.ensureInitialized().hashValue(
      this as RequestFrame,
    );
  }
}

extension RequestFrameValueCopy<$R, $Out>
    on ObjectCopyWith<$R, RequestFrame, $Out> {
  RequestFrameCopyWith<$R, RequestFrame, $Out> get $asRequestFrame =>
      $base.as((v, t, t2) => _RequestFrameCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class RequestFrameCopyWith<$R, $In extends RequestFrame, $Out>
    implements ControlMessageCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    OfferedFile,
    OfferedFileCopyWith<$R, OfferedFile, OfferedFile>
  >
  get files;
  @override
  $R call({
    String? sessionId,
    String? senderName,
    List<OfferedFile>? files,
    int? totalSize,
    bool? requestVerification,
    int? protocolVersion,
  });
  RequestFrameCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _RequestFrameCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, RequestFrame, $Out>
    implements RequestFrameCopyWith<$R, RequestFrame, $Out> {
  _RequestFrameCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<RequestFrame> $mapper =
      RequestFrameMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    OfferedFile,
    OfferedFileCopyWith<$R, OfferedFile, OfferedFile>
  >
  get files => ListCopyWith(
    $value.files,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(files: v),
  );
  @override
  $R call({
    String? sessionId,
    String? senderName,
    List<OfferedFile>? files,
    int? totalSize,
    bool? requestVerification,
    int? protocolVersion,
  }) => $apply(
    FieldCopyWithData({
      if (sessionId != null) #sessionId: sessionId,
      if (senderName != null) #senderName: senderName,
      if (files != null) #files: files,
      if (totalSize != null) #totalSize: totalSize,
      if (requestVerification != null)
        #requestVerification: requestVerification,
      if (protocolVersion != null) #protocolVersion: protocolVersion,
    }),
  );
  @override
  RequestFrame $make(CopyWithData data) => RequestFrame(
    sessionId: data.get(#sessionId, or: $value.sessionId),
    senderName: data.get(#senderName, or: $value.senderName),
    files: data.get(#files, or: $value.files),
    totalSize: data.get(#totalSize, or: $value.totalSize),
    requestVerification: data.get(
      #requestVerification,
      or: $value.requestVerification,
    ),
    protocolVersion: data.get(#protocolVersion, or: $value.protocolVersion),
  );

  @override
  RequestFrameCopyWith<$R2, RequestFrame, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _RequestFrameCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AcceptedFrameMapper extends SubClassMapperBase<AcceptedFrame> {
  AcceptedFrameMapper._();

  static AcceptedFrameMapper? _instance;
  static AcceptedFrameMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AcceptedFrameMapper._());
      ControlMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'AcceptedFrame';

  static String _$sessionId(AcceptedFrame v) => v.sessionId;
  static const Field<AcceptedFrame, String> _f$sessionId = Field(
    'sessionId',
    _$sessionId,
  );

  @override
  final MappableFields<AcceptedFrame> fields = const {#sessionId: _f$sessionId};

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'accepted';
  @override
  late final ClassMapperBase superMapper =
      ControlMessageMapper.ensureInitialized();

  static AcceptedFrame _instantiate(DecodingData data) {
    return AcceptedFrame(sessionId: data.dec(_f$sessionId));
  }

  @override
  final Function instantiate = _instantiate;

  static AcceptedFrame fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AcceptedFrame>(map);
  }

  static AcceptedFrame fromJson(String json) {
    return ensureInitialized().decodeJson<AcceptedFrame>(json);
  }
}

mixin AcceptedFrameMappable {
  String toJson() {
    return AcceptedFrameMapper.ensureInitialized().encodeJson<AcceptedFrame>(
      this as AcceptedFrame,
    );
  }

  Map<String, dynamic> toMap() {
    return AcceptedFrameMapper.ensureInitialized().encodeMap<AcceptedFrame>(
      this as AcceptedFrame,
    );
  }

  AcceptedFrameCopyWith<AcceptedFrame, AcceptedFrame, AcceptedFrame>
  get copyWith => _AcceptedFrameCopyWithImpl<AcceptedFrame, AcceptedFrame>(
    this as AcceptedFrame,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return AcceptedFrameMapper.ensureInitialized().stringifyValue(
      this as AcceptedFrame,
    );
  }

  @override
  bool operator ==(Object other) {
    return AcceptedFrameMapper.ensureInitialized().equalsValue(
      this as AcceptedFrame,
      other,
    );
  }

  @override
  int get hashCode {
    return AcceptedFrameMapper.ensureInitialized().hashValue(
      this as AcceptedFrame,
    );
  }
}

extension AcceptedFrameValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AcceptedFrame, $Out> {
  AcceptedFrameCopyWith<$R, AcceptedFrame, $Out> get $asAcceptedFrame =>
      $base.as((v, t, t2) => _AcceptedFrameCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AcceptedFrameCopyWith<$R, $In extends AcceptedFrame, $Out>
    implements ControlMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? sessionId});
  AcceptedFrameCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AcceptedFrameCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AcceptedFrame, $Out>
    implements AcceptedFrameCopyWith<$R, AcceptedFrame, $Out> {
  _AcceptedFrameCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AcceptedFrame> $mapper =
      AcceptedFrameMapper.ensureInitialized();
  @override
  $R call({String? sessionId}) =>
      $apply(FieldCopyWithData({if (sessionId != null) #sessionId: sessionId}));
  @override
  AcceptedFrame $make(CopyWithData data) =>
      AcceptedFrame(sessionId: data.get(#sessionId, or: $value.sessionId));

  @override
  AcceptedFrameCopyWith<$R2, AcceptedFrame, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AcceptedFrameCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DeclinedFrameMapper extends SubClassMapperBase<DeclinedFrame> {
  DeclinedFrameMapper._();

  static DeclinedFrameMapper? _instance;
  static DeclinedFrameMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DeclinedFrameMapper._());
      ControlMessageMapper.ensureInitialized().addSubMapper(_instance!);
      TransferFailureMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DeclinedFrame';

  static String _$sessionId(DeclinedFrame v) => v.sessionId;
  static const Field<DeclinedFrame, String> _f$sessionId = Field(
    'sessionId',
    _$sessionId,
  );
  static TransferFailure _$reason(DeclinedFrame v) => v.reason;
  static const Field<DeclinedFrame, TransferFailure> _f$reason = Field(
    'reason',
    _$reason,
  );

  @override
  final MappableFields<DeclinedFrame> fields = const {
    #sessionId: _f$sessionId,
    #reason: _f$reason,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'declined';
  @override
  late final ClassMapperBase superMapper =
      ControlMessageMapper.ensureInitialized();

  static DeclinedFrame _instantiate(DecodingData data) {
    return DeclinedFrame(
      sessionId: data.dec(_f$sessionId),
      reason: data.dec(_f$reason),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static DeclinedFrame fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DeclinedFrame>(map);
  }

  static DeclinedFrame fromJson(String json) {
    return ensureInitialized().decodeJson<DeclinedFrame>(json);
  }
}

mixin DeclinedFrameMappable {
  String toJson() {
    return DeclinedFrameMapper.ensureInitialized().encodeJson<DeclinedFrame>(
      this as DeclinedFrame,
    );
  }

  Map<String, dynamic> toMap() {
    return DeclinedFrameMapper.ensureInitialized().encodeMap<DeclinedFrame>(
      this as DeclinedFrame,
    );
  }

  DeclinedFrameCopyWith<DeclinedFrame, DeclinedFrame, DeclinedFrame>
  get copyWith => _DeclinedFrameCopyWithImpl<DeclinedFrame, DeclinedFrame>(
    this as DeclinedFrame,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return DeclinedFrameMapper.ensureInitialized().stringifyValue(
      this as DeclinedFrame,
    );
  }

  @override
  bool operator ==(Object other) {
    return DeclinedFrameMapper.ensureInitialized().equalsValue(
      this as DeclinedFrame,
      other,
    );
  }

  @override
  int get hashCode {
    return DeclinedFrameMapper.ensureInitialized().hashValue(
      this as DeclinedFrame,
    );
  }
}

extension DeclinedFrameValueCopy<$R, $Out>
    on ObjectCopyWith<$R, DeclinedFrame, $Out> {
  DeclinedFrameCopyWith<$R, DeclinedFrame, $Out> get $asDeclinedFrame =>
      $base.as((v, t, t2) => _DeclinedFrameCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DeclinedFrameCopyWith<$R, $In extends DeclinedFrame, $Out>
    implements ControlMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? sessionId, TransferFailure? reason});
  DeclinedFrameCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DeclinedFrameCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, DeclinedFrame, $Out>
    implements DeclinedFrameCopyWith<$R, DeclinedFrame, $Out> {
  _DeclinedFrameCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<DeclinedFrame> $mapper =
      DeclinedFrameMapper.ensureInitialized();
  @override
  $R call({String? sessionId, TransferFailure? reason}) => $apply(
    FieldCopyWithData({
      if (sessionId != null) #sessionId: sessionId,
      if (reason != null) #reason: reason,
    }),
  );
  @override
  DeclinedFrame $make(CopyWithData data) => DeclinedFrame(
    sessionId: data.get(#sessionId, or: $value.sessionId),
    reason: data.get(#reason, or: $value.reason),
  );

  @override
  DeclinedFrameCopyWith<$R2, DeclinedFrame, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DeclinedFrameCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class ProgressFrameMapper extends SubClassMapperBase<ProgressFrame> {
  ProgressFrameMapper._();

  static ProgressFrameMapper? _instance;
  static ProgressFrameMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProgressFrameMapper._());
      ControlMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'ProgressFrame';

  static String _$sessionId(ProgressFrame v) => v.sessionId;
  static const Field<ProgressFrame, String> _f$sessionId = Field(
    'sessionId',
    _$sessionId,
  );
  static int _$bytesReceived(ProgressFrame v) => v.bytesReceived;
  static const Field<ProgressFrame, int> _f$bytesReceived = Field(
    'bytesReceived',
    _$bytesReceived,
  );
  static String? _$fileName(ProgressFrame v) => v.fileName;
  static const Field<ProgressFrame, String> _f$fileName = Field(
    'fileName',
    _$fileName,
    opt: true,
  );

  @override
  final MappableFields<ProgressFrame> fields = const {
    #sessionId: _f$sessionId,
    #bytesReceived: _f$bytesReceived,
    #fileName: _f$fileName,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'progress';
  @override
  late final ClassMapperBase superMapper =
      ControlMessageMapper.ensureInitialized();

  static ProgressFrame _instantiate(DecodingData data) {
    return ProgressFrame(
      sessionId: data.dec(_f$sessionId),
      bytesReceived: data.dec(_f$bytesReceived),
      fileName: data.dec(_f$fileName),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ProgressFrame fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ProgressFrame>(map);
  }

  static ProgressFrame fromJson(String json) {
    return ensureInitialized().decodeJson<ProgressFrame>(json);
  }
}

mixin ProgressFrameMappable {
  String toJson() {
    return ProgressFrameMapper.ensureInitialized().encodeJson<ProgressFrame>(
      this as ProgressFrame,
    );
  }

  Map<String, dynamic> toMap() {
    return ProgressFrameMapper.ensureInitialized().encodeMap<ProgressFrame>(
      this as ProgressFrame,
    );
  }

  ProgressFrameCopyWith<ProgressFrame, ProgressFrame, ProgressFrame>
  get copyWith => _ProgressFrameCopyWithImpl<ProgressFrame, ProgressFrame>(
    this as ProgressFrame,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return ProgressFrameMapper.ensureInitialized().stringifyValue(
      this as ProgressFrame,
    );
  }

  @override
  bool operator ==(Object other) {
    return ProgressFrameMapper.ensureInitialized().equalsValue(
      this as ProgressFrame,
      other,
    );
  }

  @override
  int get hashCode {
    return ProgressFrameMapper.ensureInitialized().hashValue(
      this as ProgressFrame,
    );
  }
}

extension ProgressFrameValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ProgressFrame, $Out> {
  ProgressFrameCopyWith<$R, ProgressFrame, $Out> get $asProgressFrame =>
      $base.as((v, t, t2) => _ProgressFrameCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ProgressFrameCopyWith<$R, $In extends ProgressFrame, $Out>
    implements ControlMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? sessionId, int? bytesReceived, String? fileName});
  ProgressFrameCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ProgressFrameCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ProgressFrame, $Out>
    implements ProgressFrameCopyWith<$R, ProgressFrame, $Out> {
  _ProgressFrameCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ProgressFrame> $mapper =
      ProgressFrameMapper.ensureInitialized();
  @override
  $R call({String? sessionId, int? bytesReceived, Object? fileName = $none}) =>
      $apply(
        FieldCopyWithData({
          if (sessionId != null) #sessionId: sessionId,
          if (bytesReceived != null) #bytesReceived: bytesReceived,
          if (fileName != $none) #fileName: fileName,
        }),
      );
  @override
  ProgressFrame $make(CopyWithData data) => ProgressFrame(
    sessionId: data.get(#sessionId, or: $value.sessionId),
    bytesReceived: data.get(#bytesReceived, or: $value.bytesReceived),
    fileName: data.get(#fileName, or: $value.fileName),
  );

  @override
  ProgressFrameCopyWith<$R2, ProgressFrame, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ProgressFrameCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CompletedFrameMapper extends SubClassMapperBase<CompletedFrame> {
  CompletedFrameMapper._();

  static CompletedFrameMapper? _instance;
  static CompletedFrameMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CompletedFrameMapper._());
      ControlMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'CompletedFrame';

  static String _$sessionId(CompletedFrame v) => v.sessionId;
  static const Field<CompletedFrame, String> _f$sessionId = Field(
    'sessionId',
    _$sessionId,
  );

  @override
  final MappableFields<CompletedFrame> fields = const {
    #sessionId: _f$sessionId,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'completed';
  @override
  late final ClassMapperBase superMapper =
      ControlMessageMapper.ensureInitialized();

  static CompletedFrame _instantiate(DecodingData data) {
    return CompletedFrame(sessionId: data.dec(_f$sessionId));
  }

  @override
  final Function instantiate = _instantiate;

  static CompletedFrame fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CompletedFrame>(map);
  }

  static CompletedFrame fromJson(String json) {
    return ensureInitialized().decodeJson<CompletedFrame>(json);
  }
}

mixin CompletedFrameMappable {
  String toJson() {
    return CompletedFrameMapper.ensureInitialized().encodeJson<CompletedFrame>(
      this as CompletedFrame,
    );
  }

  Map<String, dynamic> toMap() {
    return CompletedFrameMapper.ensureInitialized().encodeMap<CompletedFrame>(
      this as CompletedFrame,
    );
  }

  CompletedFrameCopyWith<CompletedFrame, CompletedFrame, CompletedFrame>
  get copyWith => _CompletedFrameCopyWithImpl<CompletedFrame, CompletedFrame>(
    this as CompletedFrame,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return CompletedFrameMapper.ensureInitialized().stringifyValue(
      this as CompletedFrame,
    );
  }

  @override
  bool operator ==(Object other) {
    return CompletedFrameMapper.ensureInitialized().equalsValue(
      this as CompletedFrame,
      other,
    );
  }

  @override
  int get hashCode {
    return CompletedFrameMapper.ensureInitialized().hashValue(
      this as CompletedFrame,
    );
  }
}

extension CompletedFrameValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CompletedFrame, $Out> {
  CompletedFrameCopyWith<$R, CompletedFrame, $Out> get $asCompletedFrame =>
      $base.as((v, t, t2) => _CompletedFrameCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CompletedFrameCopyWith<$R, $In extends CompletedFrame, $Out>
    implements ControlMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? sessionId});
  CompletedFrameCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CompletedFrameCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CompletedFrame, $Out>
    implements CompletedFrameCopyWith<$R, CompletedFrame, $Out> {
  _CompletedFrameCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CompletedFrame> $mapper =
      CompletedFrameMapper.ensureInitialized();
  @override
  $R call({String? sessionId}) =>
      $apply(FieldCopyWithData({if (sessionId != null) #sessionId: sessionId}));
  @override
  CompletedFrame $make(CopyWithData data) =>
      CompletedFrame(sessionId: data.get(#sessionId, or: $value.sessionId));

  @override
  CompletedFrameCopyWith<$R2, CompletedFrame, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CompletedFrameCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class FailedFrameMapper extends SubClassMapperBase<FailedFrame> {
  FailedFrameMapper._();

  static FailedFrameMapper? _instance;
  static FailedFrameMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = FailedFrameMapper._());
      ControlMessageMapper.ensureInitialized().addSubMapper(_instance!);
      TransferFailureMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'FailedFrame';

  static String _$sessionId(FailedFrame v) => v.sessionId;
  static const Field<FailedFrame, String> _f$sessionId = Field(
    'sessionId',
    _$sessionId,
  );
  static TransferFailure _$reason(FailedFrame v) => v.reason;
  static const Field<FailedFrame, TransferFailure> _f$reason = Field(
    'reason',
    _$reason,
  );

  @override
  final MappableFields<FailedFrame> fields = const {
    #sessionId: _f$sessionId,
    #reason: _f$reason,
  };

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'failed';
  @override
  late final ClassMapperBase superMapper =
      ControlMessageMapper.ensureInitialized();

  static FailedFrame _instantiate(DecodingData data) {
    return FailedFrame(
      sessionId: data.dec(_f$sessionId),
      reason: data.dec(_f$reason),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static FailedFrame fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<FailedFrame>(map);
  }

  static FailedFrame fromJson(String json) {
    return ensureInitialized().decodeJson<FailedFrame>(json);
  }
}

mixin FailedFrameMappable {
  String toJson() {
    return FailedFrameMapper.ensureInitialized().encodeJson<FailedFrame>(
      this as FailedFrame,
    );
  }

  Map<String, dynamic> toMap() {
    return FailedFrameMapper.ensureInitialized().encodeMap<FailedFrame>(
      this as FailedFrame,
    );
  }

  FailedFrameCopyWith<FailedFrame, FailedFrame, FailedFrame> get copyWith =>
      _FailedFrameCopyWithImpl<FailedFrame, FailedFrame>(
        this as FailedFrame,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return FailedFrameMapper.ensureInitialized().stringifyValue(
      this as FailedFrame,
    );
  }

  @override
  bool operator ==(Object other) {
    return FailedFrameMapper.ensureInitialized().equalsValue(
      this as FailedFrame,
      other,
    );
  }

  @override
  int get hashCode {
    return FailedFrameMapper.ensureInitialized().hashValue(this as FailedFrame);
  }
}

extension FailedFrameValueCopy<$R, $Out>
    on ObjectCopyWith<$R, FailedFrame, $Out> {
  FailedFrameCopyWith<$R, FailedFrame, $Out> get $asFailedFrame =>
      $base.as((v, t, t2) => _FailedFrameCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class FailedFrameCopyWith<$R, $In extends FailedFrame, $Out>
    implements ControlMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? sessionId, TransferFailure? reason});
  FailedFrameCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _FailedFrameCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, FailedFrame, $Out>
    implements FailedFrameCopyWith<$R, FailedFrame, $Out> {
  _FailedFrameCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<FailedFrame> $mapper =
      FailedFrameMapper.ensureInitialized();
  @override
  $R call({String? sessionId, TransferFailure? reason}) => $apply(
    FieldCopyWithData({
      if (sessionId != null) #sessionId: sessionId,
      if (reason != null) #reason: reason,
    }),
  );
  @override
  FailedFrame $make(CopyWithData data) => FailedFrame(
    sessionId: data.get(#sessionId, or: $value.sessionId),
    reason: data.get(#reason, or: $value.reason),
  );

  @override
  FailedFrameCopyWith<$R2, FailedFrame, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _FailedFrameCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CancelFrameMapper extends SubClassMapperBase<CancelFrame> {
  CancelFrameMapper._();

  static CancelFrameMapper? _instance;
  static CancelFrameMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CancelFrameMapper._());
      ControlMessageMapper.ensureInitialized().addSubMapper(_instance!);
    }
    return _instance!;
  }

  @override
  final String id = 'CancelFrame';

  static String _$sessionId(CancelFrame v) => v.sessionId;
  static const Field<CancelFrame, String> _f$sessionId = Field(
    'sessionId',
    _$sessionId,
  );

  @override
  final MappableFields<CancelFrame> fields = const {#sessionId: _f$sessionId};

  @override
  final String discriminatorKey = 'type';
  @override
  final dynamic discriminatorValue = 'cancel';
  @override
  late final ClassMapperBase superMapper =
      ControlMessageMapper.ensureInitialized();

  static CancelFrame _instantiate(DecodingData data) {
    return CancelFrame(sessionId: data.dec(_f$sessionId));
  }

  @override
  final Function instantiate = _instantiate;

  static CancelFrame fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CancelFrame>(map);
  }

  static CancelFrame fromJson(String json) {
    return ensureInitialized().decodeJson<CancelFrame>(json);
  }
}

mixin CancelFrameMappable {
  String toJson() {
    return CancelFrameMapper.ensureInitialized().encodeJson<CancelFrame>(
      this as CancelFrame,
    );
  }

  Map<String, dynamic> toMap() {
    return CancelFrameMapper.ensureInitialized().encodeMap<CancelFrame>(
      this as CancelFrame,
    );
  }

  CancelFrameCopyWith<CancelFrame, CancelFrame, CancelFrame> get copyWith =>
      _CancelFrameCopyWithImpl<CancelFrame, CancelFrame>(
        this as CancelFrame,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CancelFrameMapper.ensureInitialized().stringifyValue(
      this as CancelFrame,
    );
  }

  @override
  bool operator ==(Object other) {
    return CancelFrameMapper.ensureInitialized().equalsValue(
      this as CancelFrame,
      other,
    );
  }

  @override
  int get hashCode {
    return CancelFrameMapper.ensureInitialized().hashValue(this as CancelFrame);
  }
}

extension CancelFrameValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CancelFrame, $Out> {
  CancelFrameCopyWith<$R, CancelFrame, $Out> get $asCancelFrame =>
      $base.as((v, t, t2) => _CancelFrameCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CancelFrameCopyWith<$R, $In extends CancelFrame, $Out>
    implements ControlMessageCopyWith<$R, $In, $Out> {
  @override
  $R call({String? sessionId});
  CancelFrameCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CancelFrameCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CancelFrame, $Out>
    implements CancelFrameCopyWith<$R, CancelFrame, $Out> {
  _CancelFrameCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CancelFrame> $mapper =
      CancelFrameMapper.ensureInitialized();
  @override
  $R call({String? sessionId}) =>
      $apply(FieldCopyWithData({if (sessionId != null) #sessionId: sessionId}));
  @override
  CancelFrame $make(CopyWithData data) =>
      CancelFrame(sessionId: data.get(#sessionId, or: $value.sessionId));

  @override
  CancelFrameCopyWith<$R2, CancelFrame, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CancelFrameCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

