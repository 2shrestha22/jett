import 'dart:async';
import 'dart:developer';
import 'dart:io';

// `ExternalLibrary` lives here rather than in the package's main entrypoint.
// Only the test seam at the bottom of this file needs it.
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/rust/api/transfer.dart' as rust;
import 'package:jett/rust/frb_generated.dart';
import 'package:rxdart/rxdart.dart';

/// The Rust data plane: the half of a transfer that moves bytes.
///
/// Everything that decides *whether* a transfer happens — discovery, the signed
/// attestation, the verification words, the control socket — stays in Dart.
/// This only carries file contents, and the reason it exists is that dart:io's
/// TLS pumps every byte through fixed 8 KiB buffers, which costs roughly a
/// third of the throughput on a phone. See `rust/README.md` for the numbers.
///
/// Nothing here is required for a transfer to work. If the native library will
/// not load, [available] stays false and the caller keeps to the Dart path,
/// which is the same wire protocol at a lower speed.
class DataPlane {
  DataPlane._();

  static final DataPlane instance = DataPlane._();

  bool _available = false;
  bool _initialised = false;
  int? _port;

  /// Whether the native library loaded. False means every call below is a
  /// no-op and the caller should use the Dart path.
  bool get available => _available;

  /// The port the data-plane server bound, or null if it is not listening.
  int? get port => _port;

  final _events = PublishSubject<DataPlaneEvent>();

  /// Progress and outcomes for transfers in both directions.
  ///
  /// Already throttled on the Rust side to about ten events a second per file;
  /// paying the FFI crossing per chunk is what this design exists to avoid.
  Stream<DataPlaneEvent> get events => _events.stream;

  /// Loads the native library. Safe to call more than once.
  ///
  /// Failure is not fatal and not rethrown: a build whose native library is
  /// missing for this platform should still transfer, just more slowly.
  /// [library] is only for tests and tools running outside an app bundle,
  /// which have nothing for the loader to search; see [debugDataPlaneLibrary].
  Future<void> initialize({ExternalLibrary? library}) async {
    if (_initialised) return;
    _initialised = true;
    try {
      await RustLib.init(externalLibrary: library);
      rust.initDataPlane();
      rust.dataPlaneEvents().listen(
        (event) => _events.add(DataPlaneEvent._from(event)),
        onError: (Object e) => log('Data plane event stream failed', error: e),
      );
      _available = true;
    } catch (e, s) {
      log(
        'Data plane unavailable, falling back to Dart',
        error: e,
        stackTrace: s,
      );
      _available = false;
    }
  }

  /// Starts listening and returns the port bound, or null if unavailable.
  ///
  /// Pass 0 for [port] to let the OS choose. The port is told to the sender in
  /// the acceptance frame rather than being fixed, so it cannot collide with
  /// the control server or with anything else already on the device.
  Future<int?> startServer({
    required String certificatePem,
    required String privateKeyPem,
    int port = 0,
  }) async {
    if (!_available) return null;
    try {
      _port = await rust.startServer(
        certificatePem: certificatePem,
        privateKeyPem: privateKeyPem,
        port: port,
      );
      return _port;
    } catch (e, s) {
      log('Data plane server would not start', error: e, stackTrace: s);
      _available = false;
      return null;
    }
  }

  /// Authorises a session, once the peer is verified and the user has accepted.
  ///
  /// Until this is called a request carrying [token] is answered with 404: the
  /// token is a receipt for a decision made on the control channel, not a
  /// credential in its own right. [destinations] are absolute paths this side
  /// has already chosen and sanitised, in the order the files were offered.
  Future<bool> openSession({
    required String token,
    required List<({String destination, int size})> destinations,
  }) async {
    if (!_available || _port == null) return false;
    try {
      await rust.openSession(
        token: token,
        files: [
          for (final file in destinations)
            rust.IncomingFileSpec(
              destination: file.destination,
              size: file.size,
            ),
        ],
      );
      return true;
    } catch (e, s) {
      log('Could not open a data plane session', error: e, stackTrace: s);
      return false;
    }
  }

  /// Retires a token so it cannot be replayed after the exchange is over.
  Future<void> closeSession(String token) async {
    if (!_available || _port == null) return;
    try {
      await rust.closeSession(token: token);
    } catch (e) {
      log('Could not close a data plane session', error: e);
    }
  }

  /// Stops listening, letting writes in flight finish first.
  Future<void> stopServer({Duration grace = const Duration(seconds: 5)}) async {
    if (!_available || _port == null) return;
    try {
      await rust.stopServer(graceMillis: grace.inMilliseconds);
    } catch (e) {
      log('Could not stop the data plane server', error: e);
    } finally {
      _port = null;
    }
  }

  /// Begins a send and returns a handle for [cancelSend], or null if the data
  /// plane is unavailable and the caller should send the files itself.
  ///
  /// Returns immediately. Outcomes arrive on [events], so the calling isolate
  /// is never parked for the length of a transfer.
  int? startSend({
    required String host,
    required int port,
    required String token,
    required String peerFingerprint,
    required List<({NativeSource source, int size})> files,
  }) {
    if (!_available) return null;
    try {
      return rust.startSend(
        baseUrl: 'https://$host:$port',
        token: token,
        peerFingerprint: peerFingerprint,
        files: [
          for (final file in files)
            switch (file.source) {
              NativePath(:final path) => rust.OutgoingFileSpec(
                source: path,
                size: file.size,
              ),
              // The descriptor is adopted on the other side of this call, so
              // from here on closing it is the data plane's job, not ours.
              NativeFd(:final fd) => rust.OutgoingFileSpec(
                source: '',
                fd: fd,
                size: file.size,
              ),
            },
        ],
      );
    } catch (e, s) {
      log('Could not start a data plane send', error: e, stackTrace: s);
      return null;
    }
  }

  /// Closes a descriptor opened for a send that did not go ahead.
  ///
  /// [startSend] adopts every descriptor handed to it, so this is only for the
  /// send that never started — it returning null, or the caller giving up
  /// first. Dart cannot close a raw descriptor itself, so this crosses to the
  /// side that already owns their lifetime.
  void closeDescriptor(int fd) {
    if (!_available) return;
    try {
      rust.closeDescriptor(fd: fd);
    } catch (e) {
      log('Could not close a descriptor', error: e);
    }
  }

  /// Stops a send. Whatever the peer already wrote stays there.
  void cancelSend(int taskId) {
    if (!_available) return;
    try {
      rust.cancelSend(taskId: taskId);
    } catch (e) {
      log('Could not cancel a data plane send', error: e);
    }
  }
}

/// What the data plane reports while bytes are moving.
///
/// A sealed class rather than the flat struct that crosses the boundary. The
/// boundary type stays flat so flutter_rust_bridge does not need `freezed` and
/// a second build_runner pass; the shape worth writing code against is built
/// here instead.
sealed class DataPlaneEvent {
  /// Which half of a transfer this came from: true for a send this device
  /// started, false for a file arriving.
  ///
  /// A device sending and receiving at once sees both on this one stream, and
  /// the session token cannot separate them — in a test running both ends in
  /// one process it is the same token on both sides.
  final bool sending;

  /// The session token the control channel issued, so a listener can tell
  /// whose transfer this is.
  final String session;

  /// Which of the offered files, in the order they were offered.
  final int index;

  const DataPlaneEvent({
    required this.sending,
    required this.session,
    required this.index,
  });

  factory DataPlaneEvent._from(rust.DataPlaneEvent event) =>
      switch (event.kind) {
        rust.DataPlaneEventKind.progress => DataPlaneProgress(
          sending: event.sending,
          session: event.session,
          index: event.index,
          transferred: event.transferred,
          total: event.total,
        ),
        rust.DataPlaneEventKind.fileFinished => DataPlaneFileFinished(
          sending: event.sending,
          session: event.session,
          index: event.index,
        ),
        rust.DataPlaneEventKind.failed => DataPlaneFailed(
          sending: event.sending,
          session: event.session,
          index: event.index,
          partial: event.transferred,
          message: event.message,
        ),
        rust.DataPlaneEventKind.cancelled => DataPlaneCancelled(
          sending: event.sending,
          session: event.session,
          index: event.index,
          partial: event.transferred,
        ),
      };
}

class DataPlaneProgress extends DataPlaneEvent {
  final int transferred;
  final int total;

  const DataPlaneProgress({
    required super.sending,
    required super.session,
    required super.index,
    required this.transferred,
    required this.total,
  });
}

class DataPlaneFileFinished extends DataPlaneEvent {
  const DataPlaneFileFinished({
    required super.sending,
    required super.session,
    required super.index,
  });
}

/// The transfer stopped and will not resume on its own. [partial] is what
/// survived on disk, which is where a later attempt would pick up.
class DataPlaneFailed extends DataPlaneEvent {
  final int partial;
  final String message;

  const DataPlaneFailed({
    required super.sending,
    required super.session,
    required super.index,
    required this.partial,
    required this.message,
  });
}

class DataPlaneCancelled extends DataPlaneEvent {
  final int partial;

  const DataPlaneCancelled({
    required super.sending,
    required super.session,
    required super.index,
    required this.partial,
  });
}

/// The data plane binary, for a test or a tool running outside the app bundle.
///
/// The app itself never needs this: `RustLib.init()` finds the library that
/// cargokit built into the bundle. A `dart test` process has no bundle, so it
/// has to be pointed at what `cargo build` produced.
ExternalLibrary? debugDataPlaneLibrary(String repositoryRoot) {
  for (final profile in const ['release', 'debug']) {
    for (final name in const [
      'libjett_core.so',
      'libjett_core.dylib',
      'jett_core.dll',
    ]) {
      final file = File('$repositoryRoot/rust/target/$profile/$name');
      if (file.existsSync()) return ExternalLibrary.open(file.path);
    }
  }
  return null;
}
