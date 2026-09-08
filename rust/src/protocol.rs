//! The v2 bulk-data wire format.
//!
//! Not multipart: the body of a request *is* the file content and nothing
//! parses it. The receiver seeks and writes, the sender opens and streams.
//!
//! Everything deciding *whether* a transfer may happen stays on the Dart
//! control channel; by the time a request arrives the session token is the
//! receipt for that decision.

/// Bumped when the framing below changes in a way an older peer cannot read.
/// The control channel negotiates this before any bytes move, so a v1-only
/// peer is simply never offered the v2 endpoint.
pub const DATA_PLANE_VERSION: u32 = 2;

/// `PUT /v2/blob/{token}/{index}` — body is the file content, no envelope.
pub const BLOB_PATH: &str = "/v2/blob/{token}/{index}";

/// How many bytes of file `{index}` the receiver already holds, so an
/// interrupted transfer resumes instead of restarting. Answered on `HEAD`.
pub const RECEIVED_HEADER: &str = "x-jett-received";

/// Progress is reported to Dart no more often than this. At 1 GB/s and 64 KB
/// chunks, per-chunk reporting would be ~16,000 events a second.
pub const PROGRESS_INTERVAL: std::time::Duration = std::time::Duration::from_millis(100);

/// Size of the buffer handed to the OS per read on the sending side. Large
/// enough to hide syscall overhead, small enough to stay cancellable.
pub const READ_BUFFER_BYTES: usize = 256 * 1024;
