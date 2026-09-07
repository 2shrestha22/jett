/// Version of the discovery and control protocol this build speaks.
///
/// A presence broadcast carrying no version at all comes from a build that
/// predates the control channel (v1.0.11 and earlier) and cannot be talked to.
const int kProtocolVersion = 2;

/// Version of the bulk-data path this build can use.
///
/// 1 — every file arrives in one `multipart/form-data` POST to `/upload`.
/// 2 — one raw-body `PUT /v2/blob/<session>/<index>` per file.
///
/// Negotiated per transfer rather than folded into [kProtocolVersion], which is
/// compared for strict equality and would stop a new build talking to an old
/// one at all. The two sides settle on the lower of what they each support, so
/// a v2 build still transfers with a v1 build.
///
/// Multipart makes both ends scan every byte for a boundary that may straddle
/// any two chunks. Measured at roughly half the throughput of sending the file
/// as the body — see `tool/transfer_bench.dart`.
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
