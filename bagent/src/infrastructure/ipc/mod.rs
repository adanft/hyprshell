//! The shell side: one Unix socket, one JSON object per line.
//!
//! The shell listens and this process connects, so an agent running without a
//! shell is a client with nowhere to attach rather than a server nobody visits.

pub mod link;
pub mod protocol;
