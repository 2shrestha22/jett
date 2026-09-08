import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Where an arriving file lands, and under what name. Given a directory and a
/// name a peer asked for, answers with a file that is safe to open.
class Destinations {
  /// The directory arriving files are written to. Absolute.
  final String directory;

  const Destinations(this.directory);

  /// A file in [directory] that nothing else holds, based on [requested].
  ///
  /// [claimed] are paths already handed out in this transfer but not yet
  /// created; neither exists on disk yet, so two files offered under one name
  /// would otherwise both resolve to it.
  Future<File> unused(
    String requested, {
    Set<String> claimed = const {},
  }) async {
    final fileName = safeFileName(requested);
    final extension = path.extension(fileName);
    final stem = path.basenameWithoutExtension(fileName);

    var candidate = File(path.join(directory, fileName));
    var suffix = 0;
    while (await candidate.exists() || claimed.contains(candidate.path)) {
      suffix++;
      candidate = File(path.join(directory, '$stem ($suffix)$extension'));
    }
    return candidate;
  }
}

/// The sender-supplied name, reduced to something that can only land inside
/// the download directory.
///
/// `path.join` returns an absolute path unchanged and honours `..`, so without
/// this a peer could write anywhere this process can reach. Both separators
/// are stripped whatever the host platform, since the name crosses machines.
String safeFileName(String? requested) {
  final flattened = (requested ?? '').replaceAll(r'\', '/');
  final base = flattened.split('/').last.trim();

  // Every leading dot, not just the first: "..x" would otherwise still arrive
  // hidden, and running this twice would not agree with running it once.
  final visible = base.replaceFirst(RegExp(r'^\.+'), '');

  return visible.isEmpty ? 'file' : visible;
}

/// Removes a partial file, reporting rather than throwing if it will not go,
/// so it cannot replace the error that caused the abandonment.
Future<void> deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException catch (e) {
    log('Left behind a partial file at ${file.path}', error: e);
  }
}
