import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:jett/identity/alias_words.dart';

/// The name a device announces itself under, derived from its certificate
/// fingerprint.
///
/// Derived rather than stored, so it needs nowhere to live and cannot drift
/// out of step with the key it describes. Two devices would have to land on
/// the same pair out of 16,384 to clash, which on a home or office network is
/// remote, and a clash is cosmetic: devices are told apart by their keys, not
/// their names.
String deviceAlias(String fingerprint) {
  final digest = sha256
      .convert(utf8.encode('jett-alias-v1:$fingerprint'))
      .bytes;
  final adjective = kAliasAdjectives[digest[0] & 0x7F];
  final noun = kAliasNouns[digest[1] & 0x7F];
  return '${_capitalise(adjective)} ${_capitalise(noun)}';
}

String _capitalise(String word) => word[0].toUpperCase() + word.substring(1);
