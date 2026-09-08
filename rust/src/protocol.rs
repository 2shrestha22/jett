//! The v2 bulk-data wire format.
//!
//! Deliberately not multipart. A `multipart/form-data` body forces both ends to
//! scan every byte looking for a boundary that might straddle any two chunks,
//! which is the one thing you cannot afford to do per byte on a phone. Here the
//! body of a request *is* the file content and nothing parses it: the receiver
//! seeks and writes, the sender opens and streams.
//!
//! Everything that decides *whether* a transfer may happen — pairing, the
//! signed attestation, verification words — stays on the Dart control channel.
//! By the time a request reaches this layer that decision is already made, and
//! the session token is the receipt. This keeps the reviewed security code in
//! one language and leaves Rust as a pure byte mover.

/// Bumped when the framing below changes in a way an older peer cannot read.
/// The control channel negotiates this before any bytes move, so a v1-only
/// peer is simply never offered the v2 endpoint.
pub const DATA_PLANE_VERSION: u32 = 2;

/// `PUT /v2/blob/{token}/{index}` — body is the file content, no envelope.
pub const BLOB_PATH: &str = "/v2/blob/{token}/{index}";

/// How many bytes of file `{index}` the receiver already holds, so an
/// interrupted transfer resumes instead of restarting. Answered on `HEAD`.
pub const RECEIVED_HEADER: &str = "x-jett-received";

/// Progress is reported to Dart no more often than this.
///
/// The UI cannot use more, and crossing the FFI boundary per chunk is exactly
/// the per-byte overhead this rewrite exists to remove. At 1 GB/s and 64 KB
/// chunks, per-chunk reporting would be ~16,000 events a second.
pub const PROGRESS_INTERVAL: std::time::Duration = std::time::Duration::from_millis(100);

/// Size of the buffer handed to the OS per read on the sending side.
///
/// Large enough that syscall overhead disappears against the copy, small
/// enough that cancellation is still responsive and a stalled socket does not
/// pin megabytes per concurrent transfer.
pub const READ_BUFFER_BYTES: usize = 256 * 1024;
