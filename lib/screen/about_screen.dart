import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:jett/adaptive_dialog.dart';
import 'package:jett/identity/device_identity.dart';
import 'package:jett/identity/trust_store.dart';
import 'package:jett/utils/package_info.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _clearAppData(BuildContext context) async {
    final trusted = trustStore.peers.length;

    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (context, _, _) {
        final theme = context.theme;
        return AdaptiveDialog(
          title: Text('Clear app data?'),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Text(
                trusted == 0
                    ? 'This device will get a new name and a new key.'
                    : 'This device will get a new name and a new key, and '
                          '${trusted == 1 ? 'one device it has' : '$trusted devices it has'} '
                          'verified will be forgotten.',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              Text(
                'Devices that trusted this one will ask to compare words '
                'again. Received files are not touched.',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
          actions: [
            FButton(
              variant: .secondary,
              onPress: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            FButton(
              variant: .destructive,
              onPress: () => Navigator.pop(context, true),
              child: Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await trustStore.clear();
    await DeviceIdentity.erase();
    if (!context.mounted) return;

    showFToast(
      context: context,
      title: Text('App data cleared'),
      description: Text('Reopen Jett to finish resetting this device.'),
    );
  }

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
                prefix: Icon(FLucideIcons.code),
                title: Text('Source code'),
                subtitle: Text('GitHub '),
                onPress: () {
                  launchUrlString('https://github.com/2shrestha22/jett');
                },
              ),
              FTile(
                prefix: Icon(FLucideIcons.tag),
                title: Text('Version'),
                subtitle: Text(PackageInfoHelper.version),
              ),
              FTile(
                prefix: Icon(FLucideIcons.trash2),
                title: Text('Clear app data'),
                subtitle: Text('Forget verified devices and reset this one'),
                onPress: () => _clearAppData(context),
              ),
              if (kDebugMode)
                FTile(
                  prefix: Icon(FLucideIcons.bug),
                  title: Text('Test Sentry'),
                  subtitle: Text('Press to crash'),
                  onPress: () async {
                    try {
                      throw StateError('Sentry Test Exception');
                    } catch (exception, stackTrace) {
                      await Sentry.captureException(
                        exception,
                        stackTrace: stackTrace,
                      );
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
