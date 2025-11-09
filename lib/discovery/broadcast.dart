import 'package:bonsoir/bonsoir.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/utils/device_info.dart';
import 'package:nanoid/nanoid.dart';

class BroadcastService {
  final deviceName = DeviceInfoHelper.deviceName;

  BonsoirBroadcast? _broadcast;

  Future<void> startBroadcast() async {
    final id = nanoid(10);
    _broadcast = BonsoirBroadcast(
      service: BonsoirService(
        name: id,
        type: serviceType,
        port: kTcpPort,
        attributes: {'deviceName': deviceName},
      ),
    );
    await _broadcast!.initialize();
    await _broadcast?.start();
  }

  Future<void> stopBroadcast() async {
    await _broadcast?.stop();
    _broadcast = null;
  }
}
