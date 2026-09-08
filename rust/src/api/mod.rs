//! Everything Dart can call. Deliberately small.
//!
//! The boundary is a control plane: start a server, authorise a session, begin
//! a send, cancel it, and receive progress. File bytes never appear in any
//! signature here — that is the property the whole port exists to preserve.
pub mod transfer;
