import 'package:flutter/widgets.dart';
import 'package:forui/theme.dart';
import 'package:jett/messages.g.dart';

class PluginCheckWidget extends StatefulWidget {
  const PluginCheckWidget({super.key});

  @override
  State<PluginCheckWidget> createState() => _PluginCheckWidgetState();
}

class _PluginCheckWidgetState extends State<PluginCheckWidget> {
  final api = JettApi();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: api.getPlatformVersion(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text(
            snapshot.data!.string!,
            style: context.theme.typography.xs,
          );
        }
        return Text('');
      },
    );
  }
}
