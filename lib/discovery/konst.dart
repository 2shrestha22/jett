/// Version of the discovery and control protocol this build speaks.
///
/// A presence broadcast carrying no version at all comes from a build that
/// predates the control channel (v1.0.11 and earlier) and cannot be talked to.
const int kProtocolVersion = 2;

/// Version of the bulk-data path this build can use.
///
/// 2 — one raw-body `PUT /v2/blob/<session>/<index>` per file. Version 1, a
/// `multipart/form-data` POST to `/upload`, is gone.
///
/// Negotiated per transfer rather than folded into [kProtocolVersion], which is
/// compared for strict equality. The two sides settle on the lower of what they
/// support.
///
/// Doubles as the floor: a peer below it is refused while it is still asking.
/// When a 3 exists the floor has to become a constant of its own.
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
