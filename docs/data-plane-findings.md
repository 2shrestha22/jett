# Rust data plane: findings

Investigation of "the Rust data plane is integrated but transfers are not
faster", and the work that followed from it. Opened 2026-09-07, resolved the
same day.

Every claim below is tagged with how it is known. Nothing is asserted that was
not either measured or read directly out of the source.

| tag | meaning |
|---|---|
| **[MEASURED]** | a number someone actually observed, with the conditions stated |
| **[CODE]** | read directly from this repository, with `file:line` |
| **[INFERRED]** | a conclusion drawn from the above; the reasoning is given |
| **[UNVERIFIED]** | a hypothesis that has *not* been tested |

---

## 1. Outcome

**[MEASURED]** jett over WiFi now moves **34 MB/s**, against **12–20 MB/s**
before. `iperf3` between the same two devices measures the link at **30–34
MB/s**.

**[INFERRED, high confidence]** The transfer is now limited by the network
rather than by jett. The application matches raw TCP while additionally doing
TLS and writing every byte to disk, so there is no headroom left to recover on
this link.

The cause was not what the integration looked like from the outside. The Rust
data plane had been wired in correctly and had never carried a single byte,
because a guard in the sender rejected every file Android can produce. §2 is
the evidence, §3 the cause, §4 the fix.

---

## 2. Measurements

### 2.1 Dart's TLS record size — the root cause of the Dart ceiling

**[MEASURED]** A TCP proxy that parses TLS record headers without decrypting
(`bench/tool/tls_record_proxy.dart` in the xferbench repo), 32 MiB in each
direction over one connection:

| sender | records | mean record |
|---|---:|---:|
| curl 8.5.0 / OpenSSL 3.0.13 | 2,054 | **16,353 B** |
| `dart:io` `HttpServer` | 8,709 | **3,870 B** |

TLS 1.3 permits 16,384 plaintext bytes per record. OpenSSL uses effectively all
of it; `dart:io` averages under a quarter. The OpenSSL row is a control run
through the same proxy and parser, so the difference is not a measurement
artefact.

**[CODE]** `dart-lang/sdk`, `sdk/lib/_internal/vm/bin/secure_socket_patch.dart`:

    static final int SIZE = 8 * 1024;
    static final int ENCRYPTED_SIZE = 10 * 1024;

`static final`, no public API to change them.

**[CODE]** `dart-lang/sdk`, `runtime/bin/secure_socket_filter.cc`: the native
side reads those two values from Dart and rejects only
`buffer_size <= 0 || buffer_size > 1 * MB`. The native layer would accept 1 MB.

**[INFERRED]** The ~4 KiB observed records, against an 8 KiB declared buffer,
are consistent with the buffer being *circular*: `SSL_write` is handed one
contiguous segment at a time, and in steady state the free contiguous run
averages about half the ring. Note also that a 10 KiB encrypted buffer cannot
hold a maximum-size record (16,405 B on the wire), so full-size records are
structurally impossible.

### 2.2 Desktop loopback (xferbench)

**[MEASURED]** Intel i3-5005U, 2 cores / 4 threads, Linux, Dart 3.13.2 AOT vs
release Rust. 64 MiB single file, best of 3, **receiver discards the bytes
(memory sink, nothing written to disk)**.

| pair | up MiB/s | down MiB/s | CPU s/MiB (up) |
|---|---:|---:|---:|
| `rust-http` | 1970.0 | 2023.7 | 0.0011 |
| `dart-raw-tcp` | 582.3 | 599.9 | 0.0033 |
| `rust-https` | 553.6 | 708.9 | 0.0037 |
| `dart-http` | 543.6 | 520.3 | 0.0034 |
| `curl-http` → Dart server | 527.0 | 1071.1 | 0.0037 |
| `curl-rust-https` | 314.4 | 516.8 | 0.0066 |
| `dart-https-isolates` (4 isolates) | 75.0 | 68.2 | 0.0352 |
| `rust-server-dart-client` | 68.6 | 39.4 | 0.0305 |
| `dart-https` | 58.1 | 60.5 | 0.0380 |
| `dart-raw-tls` | 54.6 | 55.1 | 0.0431 |
| `curl-https` → Dart server | 47.8 | 73.0 | 0.0275 |
| `dart-server-rust-client` | 44.6 | 71.3 | 0.0286 |

Four things follow, all directly from the table:

- **It is TLS, not HTTP.** `dart-raw-tls` (bare socket, 16-byte header, no HTTP)
  is 54.6 — no faster than `dart-https` at 58.1. Removing HTTP entirely buys
  nothing. `dart-raw-tcp` at 582.3 shows the socket layer is not the limit.
- **Either end being Dart+TLS caps the transfer.** Rust-server/Dart-client
  (68.6) and Dart-server/Rust-client (44.6) both sit in the same 40–75 band as
  `dart-https`, while Rust-both-ends is 553.6.
- **Not the TLS library or the client.** The same curl/OpenSSL client gets
  527.0 against the Dart server without TLS, 47.8 with it, and 314.4 against
  rustls.
- **Parallel isolates do not fix it.** 58.1 → 75.0 on 4 threads (1.29x), and
  CPU per MiB barely moves.

### 2.3 Android phone, loopback (xferbench app)

**[MEASURED]** One Android arm64 device, `127.0.0.1`, release build,
**memory sink**.

| pair | up MiB/s | down MiB/s | CPU s/MiB up | CPU s/MiB down |
|---|---:|---:|---:|---:|
| `rust-http` | 3089 | 4516 | — | — |
| `rust-https` | 767 | 810 | 0.0025 | 0.0023 † |
| `dart-http` | 674 | 706 | — | — |
| `dart-https` | 36 | 35 | 0.0581 | 0.0650 |

† reported as "00.23"; read as 0.0023 because it is consistent with the higher
download throughput. **Not independently confirmed — re-check if it matters.**

Derived: Dart TLS penalty 18.7x up / 20.2x down. `rust-https` over
`dart-https` 21.3x up / 23.1x down. CPU per byte 23.2x up / 28.3x down.

**[MEASURED]** Same code, phone ÷ desktop, upload: `rust-http` 1.57x,
`rust-https` 1.39x, `dart-http` 1.24x, **`dart-https` 0.62x**.

**[INFERRED]** Every path is faster on the phone except `dart:io` HTTPS, which
is slower in absolute terms than on a 2015 i3. Bulk AES scales with the CPU;
this does the opposite. That is consistent with per-record round-trip overhead
(event-loop turns, syscalls, scheduling) rather than encryption cost, and with
§2.1. It is not consistent with a bulk-throughput bottleneck.

### 2.4 jett on device, before the fix

**[MEASURED]** jett's About screen (ⓘ, top-right of home → "Transfer engine")
after a send:

    Native available · port ****
    Sent: ... 94mb file is a content:// URI, not a file

The first line means the native library loaded. The second is the
`fellBackBecause` string, printed only when Dart carried the transfer.

**[MEASURED]** jett over WiFi, a 94 MB file from the gallery. Both rows are
therefore the **Dart** path, and the receiver **writes to disk**:

| jett configuration | MB/s |
|---|---:|
| Dart + HTTP | **30** |
| Dart + HTTPS | **12–20** |

**[INFERRED]** ~2x for TLS in Dart under these conditions. Also: reading a
`content://` source through Dart sustains 30 MB/s, so the URI is not itself
slow — the fallback it triggers is what costs.

### 2.5 jett on device, after the fix — and the link ceiling

**[MEASURED]** jett over WiFi, same shape of transfer: **34 MB/s**.

**[MEASURED]** `iperf3` between the same two devices: **30–34 MB/s**. This is
the number that had never been measured and without which none of the rows
above could be told apart from "still slow".

Everything on one axis, WiFi, receiver writing to disk except where noted:

| path | MB/s | |
|---|---:|---|
| Dart + HTTPS | 12–20 | software-bound, well under the link |
| Dart + HTTP, no TLS | 30 | at the link |
| **Rust + TLS** | **34** | at the link |
| `iperf3`, raw TCP | 30–34 | the link itself |

**[INFERRED, high confidence]** Both ways of taking `dart:io`'s TLS out of the
path arrive at the ceiling, and nothing else does. That is §2.1 confirmed end
to end: the 8 KiB record buffers were the whole gap, and they were costing
about half the link.

**[INFERRED]** jett matches raw TCP while also doing TLS and writing to
FUSE-backed storage, so both are now free relative to the network. This also
retires the `set_len` question in §3.5: preallocation cannot be costing
anything measurable if the transfer is sitting on the link ceiling.

**[UNVERIFIED]** The About screen has **not** been read since the fix. The
numbers are consistent with both halves running native, but a native sender
with a Dart receiver would look identical at a link ceiling this low. Read it
once to close this out.

### 2.6 iOS

**[MEASURED]** The iOS build compiles, runs, and was reported as "even faster"
than Android. **No figures were recorded.** Nothing quantitative should be
claimed about iOS.

Note for whoever measures it: the `CPU s/MiB` column will be empty on iOS — it
reads `/proc/self/stat`, which iOS does not have.

---

## 3. The cause

### 3.1 The guard

**[CODE]** The sender decided whether Rust could take a file by testing whether
`resource.identifier` started with `/`, as a proxy for "this is a real file".
The proxy was wrong in three separate ways, and on Android it was wrong every
single time:

1. **Android had no path, ever.** Every route into the app produces a
   `ContentResource`: SAF picks (`picker_buttons.dart`), the gallery stream and
   share intents (`platform_api.dart`), the APK picker
   (`apk_picker_screen.dart`). `fast_file_picker` on Android delegates to
   `saf_util.pickFiles` and returns `FastFilePickerPath.fromUri(...)` with
   `path` left null — there is no setting that changes this. So the identifier
   was always `content://…` and the guard always rejected it.
2. **Desktop drops mangled a good path.** Files dropped on the window arrive as
   absolute paths, were wrapped in `ContentResource`, and `_ensureFileUri` turned
   `/home/x/f.bin` into `file:///home/x/f.bin` — which no longer starts with `/`.
   A perfectly openable local file was rejected by a guard meant for content URIs.
3. **Windows never matched at all.** `C:\Users\…` does not start with `/`, so
   even a plain `FileResource` failed.

**[INFERRED]** Because the send fell back, the receive fell back too: a Dart
send is answered by the Dart handlers on the control port, so the Rust server
sat with an authorised session that never received a `PUT`. **Both halves of
the data plane were dark, and every jett throughput number recorded before
§2.5 was `dart:io` TLS.**

### 3.2 Why the URI was blamed, and why that was wrong

**[CODE]** `uri_content`'s Android plugin (`UriContentPlugin.kt:141`) calls
`contentResolver.openInputStream` and ships the file to Dart as `ByteArray`
chunks over a platform channel.

**[INFERRED]** A `content://` URI is an efficient *handle*. What cost was
reading through it: every byte crossed Kotlin, then Dart, then `dart:io`'s TLS.
The URI was never the problem; using it as a byte pipe was.

---

## 4. What was done

### 4.1 A descriptor instead of a byte stream

**[CODE]** `openFileDescriptor` on the existing `JettHostApi`
(`pigeons/input.dart`), implemented at
`android/app/src/main/kotlin/com/sangamshrestha/jett/MainActivity.kt:102`. It
calls `contentResolver.openFileDescriptor(uri, "r")` and returns
`detachFd()`.

`detachFd` rather than `fd`: it transfers ownership, so the
`ParcelFileDescriptor` going out of scope does not close a descriptor Rust is
about to read. Using `fd` would be a use-after-close.

One integer now crosses per file, instead of every byte.

**[CODE]** iOS implements the method only because the channel is shared, and
throws (`ios/Runner/AppDelegate.swift`). Its sources already resolve to paths.

### 4.2 Descriptor ownership

Nothing closes a detached descriptor unless someone takes responsibility, and
leaking them exhausts the process. Ownership is therefore pinned in three
places:

**[CODE]** `rust/src/api/transfer.rs:349` — `start_send` adopts every incoming
fd into an `OwnedFd` **before anything can fail**. Dropping it closes it, so an
error, a cancellation, or a file the loop never reaches because an earlier one
failed all release without a line of code saying so.

**[CODE]** `rust/src/client.rs:21` — `FileSource` is `Path` or `Descriptor`,
and `OutgoingFile` is deliberately not `Clone`: a descriptor has exactly one
owner, and duplicating one would mean two closes of the same number.

**[CODE]** `lib/transfer/client.dart:423,514,527` — one `adopted` flag and one
`finally` covers every way out of `_sendNatively` before the handoff. An
earlier version released by hand at each exit and left a gap between opening
the descriptors and the `try` that hands them over.

**[CODE]** `rust/src/api/transfer.rs:397` — `close_descriptor`, for the send
that never starts. Dart cannot close a raw descriptor itself.

### 4.3 The guard, replaced

**[CODE]** `lib/model/resource.dart:69` — `Resource.nativeSource()` returns a
`NativePath`, a `NativeFd`, or null. "Can Rust open this?" is now a property of
the type rather than the shape of a string, which is what kills all three cases
in §3.1 at once. `lib/transfer/client.dart:399` asks the resource instead of
inspecting its identifier.

### 4.4 Two bugs found on the way

**[CODE]** `lib/model/resource.dart:197` — `_ensureFileUri` built URIs by
string concatenation, so `C:\dir\f.bin` parsed as **scheme `c`** and named
nothing. That broke reading on Windows, not just the native path. Now uses
`Uri.file`, which also escapes spaces the old form left raw.

**[CODE]** `lib/discovery/konst.dart:30` — data plane v1 (`multipart/form-data`
to `/upload`) was removed. No reachable peer could ask for it: the control
channel and the raw-body path both landed after v1.0.10, the last release, so
anything that can negotiate at all already speaks v2. `kMinDataPlaneVersion` is
the floor, and both ends refuse below it early rather than failing once bytes
are moving.

### 4.5 Tests

**[CODE]** `rust/tests/data_plane.rs:383` —
`transfers_a_file_given_only_a_descriptor` sends with no path at all and then
asserts the descriptor was closed, which is the leak this design has to avoid.

**[CODE]** `test/model/resource_test.dart` — what each resource kind offers the
data plane, including the three cases the old guard got wrong.

Suites at the time of writing: **99 Dart, 10 Rust, `flutter analyze` clean.**

---

## 5. Open, for whoever picks this up

1. **Read the About screen.** §2.5 is the only [UNVERIFIED] item that affects
   the conclusion. It should say `Sent: Native` and `Received: Native`.
2. **Kotlin and Swift have never been compiled.** They were written on a
   headless Linux box with no Android SDK and no Xcode. The Kotlin is six lines
   against an existing channel; the Swift throws. A device build is the first
   real check of both.
3. **CPU per byte is the win still on the table.** §2.3 measured ~23x, and it
   does not depend on link speed — same wall clock on WiFi, materially less
   battery and heat. Nobody has measured it in jett itself.
4. **A faster link is where this keeps paying.** Dart capped at 12–20 whatever
   it was plugged into; Rust does 767 MB/s over phone loopback (§2.3). On 6 GHz
   or a wired tether the gap should reopen. Untested.
5. **A resume over a non-seekable descriptor fails.** A document provider may
   hand back a pipe. A fresh send is fine — only a resume seeks
   (`rust/src/client.rs`) — and the error names the file, but there is no
   fallback. Unobserved so far.
6. **The fallback is still per batch, not per file.** One resource that cannot
   offer a native source sends the whole batch through Dart. This was worth
   fixing when Android always fell back; now that it never does, it is close to
   dead code. Left alone deliberately — per-file mixing would complicate the
   batch-wide file indices the receiver's destinations are keyed by.

---

## 6. Corrections made during this investigation

Recorded so they are not repeated.

- **"The integration is finished, the link is the ceiling."** Wrong when it was
  said, though it happens to be true now. It came from treating xferbench's
  two-device number as jett's, and jett's Rust path had not run.
- **"`content://` is not a throughput problem."** Wrong, and it followed from
  the same mistake — it assumed the 12–20 MB/s figure came from the native
  path. It came from Dart.
- **The `set_len`/FUSE diagnosis was offered before checking which path was in
  use.** Premature: that code had never executed. §2.5 has since retired it for
  a different reason.
- **The guard was first described as a `content://` problem only.** It was
  three problems — see §3.1. Reading the construction sites rather than the
  guard is what surfaced the other two.

The general lesson, unchanged and now paid for twice: **read the About screen
first.** It distinguishes all of these in one transfer, and every wrong turn
above came from reasoning about throughput before establishing which code path
produced it.

---

## 7. Reference

- Benchmark, method, full numbers and raw output:
  `github.com/2shrestha22/xferbench` (private). `README.md` for analysis,
  `results/phone_loopback.txt` and `results/local_aot.txt` for figures,
  `results/tls_record_sizes.txt` for §2.1.
- This repo's earlier measurements and the reasoning behind the port:
  `rust/README.md`.
- `tool/transfer_bench.dart` measures the Dart path in isolation. Its multipart
  configuration was removed with §4.4.
