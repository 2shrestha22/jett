//! What the Rust side tells Dart while bytes are moving.
//!
//! One channel for both directions, since the UI draws them with the same
//! widgets.

use tokio::sync::mpsc::UnboundedSender;

/// Which half of a transfer an event came from.
///
/// The session token alone cannot tell them apart, since both halves share one
/// stream. Stamped where the event is emitted.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Direction {
    Sending,
    Receiving,
}

#[derive(Debug, Clone)]
pub enum TransferEvent {
    /// Throttled to [`crate::protocol::PROGRESS_INTERVAL`]; also emitted once
    /// when a file completes so the last frame is never a stale 99%.
    Progress {
        session: String,
        index: u32,
        transferred: u64,
        total: u64,
    },
    FileFinished {
        session: String,
        index: u32,
    },
    /// The transfer stopped and will not resume on its own. `partial` is what
    /// survived on disk, where a later resume starts.
    Failed {
        session: String,
        index: u32,
        partial: u64,
        message: String,
    },
    Cancelled {
        session: String,
        index: u32,
        partial: u64,
    },
}

/// Where events go. Cloneable; dropping every clone stops delivery rather than
/// failing the transfer.
#[derive(Clone)]
pub struct EventSink {
    sender: Option<UnboundedSender<(Direction, TransferEvent)>>,
    direction: Direction,
}

impl EventSink {
    pub fn new(sender: UnboundedSender<(Direction, TransferEvent)>, direction: Direction) -> Self {
        Self {
            sender: Some(sender),
            direction,
        }
    }

    /// The same destination, stamped as the other half of a transfer.
    pub fn for_direction(&self, direction: Direction) -> Self {
        Self {
            sender: self.sender.clone(),
            direction,
        }
    }

    /// For callers that want the bytes moved and nothing reported.
    pub fn silent() -> Self {
        Self {
            sender: None,
            direction: Direction::Receiving,
        }
    }

    pub fn send(&self, event: TransferEvent) {
        if let Some(sender) = &self.sender {
            // A closed receiver means Dart went away; the transfer carries on.
            let _ = sender.send((self.direction, event));
        }
    }
}

/// Emits progress no more than once per [`PROGRESS_INTERVAL`], plus a final
/// exact reading.
///
/// Rate limited here rather than in Dart so the FFI crossing is never paid.
pub struct ProgressThrottle {
    sink: EventSink,
    session: String,
    index: u32,
    total: u64,
    transferred: u64,
    last_emit: std::time::Instant,
}

impl ProgressThrottle {
    pub fn new(sink: EventSink, session: String, index: u32, total: u64, resumed_at: u64) -> Self {
        Self {
            sink,
            session,
            index,
            total,
            transferred: resumed_at,
            // Set back far enough that the first chunk emits immediately, so a
            // resumed transfer shows its starting point at once.
            last_emit: std::time::Instant::now() - crate::protocol::PROGRESS_INTERVAL,
        }
    }

    pub fn advance(&mut self, bytes: u64) {
        self.transferred += bytes;
        if self.last_emit.elapsed() >= crate::protocol::PROGRESS_INTERVAL {
            self.last_emit = std::time::Instant::now();
            self.emit();
        }
    }

    pub fn transferred(&self) -> u64 {
        self.transferred
    }

    /// Final reading, unconditionally.
    pub fn flush(&mut self) {
        self.emit();
    }

    fn emit(&self) {
        self.sink.send(TransferEvent::Progress {
            session: self.session.clone(),
            index: self.index,
            transferred: self.transferred,
            total: self.total,
        });
    }
}
