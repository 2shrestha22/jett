import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:jett/utils/package_info.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        prefixes: [
          FHeaderAction.x(
            onPress: () {
              Navigator.of(context).pop();
            },
          ),
        ],
        title: Text('About'),
      ),
      child: Column(
        children: [
          FTileGroup(
            children: [
              FTile(
                prefix: Icon(FIcons.code),
                title: Text('Source code'),
                subtitle: Text('GitHub '),
                onPress: () {
                  launchUrlString('https://github.com/2shrestha22/jett');
                },
              ),
              FTile(
                prefix: Icon(FIcons.tag),
                title: Text('Version'),
                subtitle: Text(PackageInfoHelper.version),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
