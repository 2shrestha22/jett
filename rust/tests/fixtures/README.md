# Interop fixture

A throwaway identity, minted by Jett's own `DeviceKeys.generate()`, that both
languages assert against so they can never disagree about how a key is named.
See `rust/tests/dart_interop.rs` and `test/crypto/fingerprint_interop_test.dart`.

`dart_identity.key` is a private key, and it is committed on purpose. It was
generated for this fixture, has never been a device's identity, and guards
nothing — a device mints its own on first run and keeps it in the app's support
directory. Do not reuse it for anything.

Regenerating changes the expected fingerprint, so only do it deliberately:

    mise exec -- dart run tool/gen_fixture.dart
