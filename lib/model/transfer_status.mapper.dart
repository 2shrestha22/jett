// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'transfer_status.dart';

class TransferFailureMapper extends EnumMapper<TransferFailure> {
  TransferFailureMapper._();

  static TransferFailureMapper? _instance;
  static TransferFailureMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = TransferFailureMapper._());
    }
    return _instance!;
  }

  static TransferFailure fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  TransferFailure decode(dynamic value) {
    switch (value) {
      case r'declined':
        return TransferFailure.declined;
      case r'busy':
        return TransferFailure.busy;
      case r'peerUnreachable':
        return TransferFailure.peerUnreachable;
      case r'timeout':
        return TransferFailure.timeout;
      case r'fileUnreadable':
        return TransferFailure.fileUnreadable;
      case r'storageError':
        return TransferFailure.storageError;
      case r'versionMismatch':
        return TransferFailure.versionMismatch;
      case r'unverifiedSender':
        return TransferFailure.unverifiedSender;
      case r'unknown':
        return TransferFailure.unknown;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(TransferFailure self) {
    switch (self) {
      case TransferFailure.declined:
        return r'declined';
      case TransferFailure.busy:
        return r'busy';
      case TransferFailure.peerUnreachable:
        return r'peerUnreachable';
      case TransferFailure.timeout:
        return r'timeout';
      case TransferFailure.fileUnreadable:
        return r'fileUnreadable';
      case TransferFailure.storageError:
        return r'storageError';
      case TransferFailure.versionMismatch:
        return r'versionMismatch';
      case TransferFailure.unverifiedSender:
        return r'unverifiedSender';
      case TransferFailure.unknown:
        return r'unknown';
    }
  }
}

extension TransferFailureMapperExtension on TransferFailure {
  String toValue() {
    TransferFailureMapper.ensureInitialized();
    return MapperContainer.globals.toValue<TransferFailure>(this) as String;
  }
}

