/// Version of the discovery and control protocol this build speaks.
///
/// A presence broadcast carrying no version at all comes from a build that
/// predates the control channel (v1.0.11 and earlier) and cannot be talked to.
const int kProtocolVersion = 2;

/// Version of the bulk-data path this build can use.
///
/// 2 — one raw-body `PUT /v2/blob/<session>/<index>` per file.
///
/// Negotiated per transfer rather than folded into [kProtocolVersion], which is
/// compared for strict equality and would stop a new build talking to an old
/// one at all. The two sides settle on the lower of what they each support.
///
/// Version 1 put every file in one `multipart/form-data` POST to `/upload`. It
/// is gone — both ends had to scan every byte for a boundary that might
/// straddle any two chunks — and it cost no peer anything, because the control
/// channel and the raw-body path both landed after v1.0.10, the last release.
/// Anything that can negotiate at all already speaks 2.
///
/// This doubles as the floor: a peer below it is refused while it is still
/// asking, rather than accepted and then failed once its bytes are moving.
/// When a 3 exists the floor stops being the newest version and has to become
/// a constant of its own.
const int kDataPlaneVersion = 2;

const int kUdpPort = 37020;
const String kAddress = '239.255.0.1';
const int kTcpPort = 37021;

// Constants for device discovery and communication
const Duration cleanUpInterval = Duration(milliseconds: 1000);
const Duration pingInterval = Duration(milliseconds: 2000);
const Duration deviceTimeout = Duration(milliseconds: 3000);

const appName = 'Jett';
const dot = '•';
