import 'package:bonsoir/bonsoir.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/model/device.dart';
import 'package:jett/utils/rx_list.dart';

class DiscoveryService {
  BonsoirDiscovery? discovery;

  final _deviceList = RxList<Device>();
  Stream<List<Device>> get deviceStream => _deviceList.stream.distinct();

  void startDiscovert() async {
    discovery = BonsoirDiscovery(type: serviceType);
    await discovery!.initialize();

    discovery!.eventStream!.listen((event) {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          _deviceList.addItem(
            Device(
              id: event.service.name,
              ipAddress: event.service.host,
              port: event.service.port,
              name: event.service.attributes['deviceName'] ?? 'Unknown',
            ),
          );
          // event.service.resolve(
          //   discovery!.serviceResolver,
          // ); // Should be called when the user wants to connect to this service.
          break;
        case BonsoirDiscoveryServiceResolvedEvent():
          print('Service resolved : ${event.service.toJson()}');
          break;
        case BonsoirDiscoveryServiceUpdatedEvent():
          _deviceList.removeWhere((item) => item.name == item.id);
          _deviceList.addItem(
            Device(
              id: event.service.name,
              ipAddress: event.service.host,
              port: event.service.port,
              name: event.service.attributes['deviceName'] ?? 'Unknown',
            ),
          );
          break;
        case BonsoirDiscoveryServiceLostEvent():
          _deviceList.removeWhere((item) => item.name == item.id);
          break;
        default:
          print('Another event occurred : $event.');
          break;
      }
    });

    await discovery!.start();
  }

  void stopDiscovery() async {
    await discovery?.stop();
    discovery = null;
  }
}
