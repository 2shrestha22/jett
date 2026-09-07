# jett_core — the data plane

Moves file bytes and nothing else. Discovery, pairing, the signed attestation,
verification words and the control-channel WebSocket all stay in Dart, where
they are already written and reviewed. The FFI surface here is a *control plane
for byte movement*: no file content appears in any signature crossing it.

## Why

The Dart path sends and receives through `multipart/form-data`
(`lib/transfer/server.dart:337`, `lib/transfer/client.dart:348`). That forces
both ends to scan every byte for a boundary that may straddle any two chunks,
then copy the payload onto the Dart heap on the way to disk.

Here, a request body *is* the file. The receiver seeks and writes; the sender
opens and streams. Nothing parses the payload, and the only thing reaching Dart
is a progress event ten times a second.

## State — 2026-09-06

Working and tested. **Not yet wired into the app.**

| | |
|---|---|
| Rust core | done — 9 tests passing |
| Dart/Rust interop | verified against a fixture Dart minted |
| FFI bindings | generated (`lib/rust/`) |
| Benchmark (step 1) | done — see below |
| Dart wrapper | **not written** |
| Platform builds | **not set up** (no cargokit yet) |
| App integration | **not started** |

Nothing existing was modified except one `pubspec.yaml` line, added by codegen.
The full Dart suite (69 tests) still passes.

### Measured — 2026-09-07

512 MiB over TLS + HTTP onto disk, loopback, AOT-compiled Dart against
release-mode Rust, server in its own isolate/runtime in both cases.

| | | |
|---|---:|---|
| A  multipart + `openWrite` | **22 MB/s** | what Jett did before |
| B  raw PUT + `openWrite` | **46 MB/s** | multipart removed |
| C  raw PUT + 1 MiB write buffer | **45 MB/s** | buffering adds nothing |
| E  raw PUT, as `server.dart` does it | **45 MB/s** | B plus the speedometer, progress clock and stall timeout the real handler runs per chunk |
| D  raw PUT, **no TLS** | **289 MB/s** | diagnostic only |
| **Rust data plane** | **230 MB/s** | TLS included |

Reproduce with `tool/transfer_bench.dart` and `rust/tests/throughput.rs`.

Two separate costs, and the second is the big one:

**Multipart costs about 2x.** 22 → 46 MB/s just by making the body the file.
Configuration E adds back everything else `server.dart` does per chunk —
counting into the speedometer, checking the clock for a progress frame, the
stall timeout — and loses nothing, so the win is not eaten by the surrounding
code. This is done; see `lib/transfer/server.dart` and `konst.dart`.

One caveat on that number. `flutter test` runs a JIT VM, and measured there the
same two paths come out at 8 and 9 MB/s — a 1.2x gap, not 2x. Everything is
slower under JIT, and the shared TLS cost below grows enough to swamp the
difference between the paths. Release builds are AOT, so the table above is the
representative one; the real server could not be AOT-measured directly because
`server.dart` imports `package:flutter/foundation.dart` and will not compile
standalone, which is why configuration E reproduces its handler instead.

**Dart's TLS costs about 6x, and there is no way around it in Dart.**
Configuration D is the same Dart, same HTTP stack, same disk — 287 MB/s, which
is *faster than the Rust path with TLS*. Dart's HTTP and file handling were
never the problem. `dart:io` pumps every TLS byte through fixed ring buffers
sized in `sdk/lib/_internal/vm/bin/secure_socket_patch.dart`:

    static final int SIZE = 8 * 1024;
    static final int ENCRYPTED_SIZE = 10 * 1024;

That is ~65,000 round trips through the Dart/native boundary for a 512 MiB
file. They are `static final` with no public API to change them, so this is a
ceiling, not a tuning knob.

Jett always runs encrypted — the whole verification design depends on it — so
that ceiling is load-bearing. **This is what justifies the port**, and it is a
narrower claim than "Dart is slow": Dart's TLS is slow, and nothing else here is.

Caveats worth keeping in mind. These are loopback numbers on a desktop, so they
measure the stack's ceiling, not a field result; mobile CPUs will be lower
across the board, though the ratios should roughly hold. At ~46 MB/s Dart is
still near the limit of typical WiFi 5, so the win is largest on WiFi 6, wired
links, and — on phones — in CPU and battery per byte rather than in wall clock.

## Layout

    src/protocol.rs     wire format and tuning constants, with the reasoning
    src/fingerprint.rs  SHA-256 of the DER SubjectPublicKeyInfo, as Dart computes it
    src/tls.rs          rustls from Dart's PEMs; pins peers by key fingerprint
    src/server.rs       axum: PUT is a seek and a write
    src/client.rs       reqwest: streams off disk, resumes, cancels
    src/api/transfer.rs the FFI surface — ten functions
    src/frb_generated.rs  generated, do not edit

## The interop fixture

`tests/fixtures/dart_identity.*` was minted by Jett's own `DeviceKeys.generate()`.
Both languages assert against it — `tests/dart_interop.rs` and
`test/crypto/fingerprint_interop_test.dart` — because if the two sides ever
disagree about how a key is named, every stored trust relationship silently
breaks and devices stop recognising peers they have already verified.

Regenerate only if deliberately replacing it:

    mise exec -- dart run tool/gen_fixture.dart

## Next, in order

1. ~~Benchmark the current Dart path.~~ Done — the port is justified, see
   **Measured** above. Independently of the port, dropping multipart is a 2x
   win on the existing Dart code and could ship on its own.
2. `lib/transfer/data_plane.dart` — a hand-written wrapper turning the flat
   `DataPlaneEvent` into a Dart 3 sealed class. Kept flat across FFI so
   flutter_rust_bridge does not need `freezed` and a second build_runner pass.
3. Platform builds via cargokit — Android (4 ABIs), iOS xcframework, macOS,
   Windows, Linux.
4. Negotiate `DATA_PLANE_VERSION` on the control channel so a v1-only peer is
   never offered the v2 endpoint.

## Regenerating bindings

    flutter_rust_bridge_codegen generate

Needs `flutter` on PATH, which mise does not export by default:

    export PATH="$HOME/.local/share/mise/installs/flutter/3.47.2/bin:$PATH"
