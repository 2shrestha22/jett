import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:jett/screen/send/online_devices.dart';
import 'package:jett/screen/send/presence_notifier.dart';
import 'package:jett/theme/theme.dart';

/// The empty state of the device list.
///
/// A spinner that never resolves is the worst thing this screen can show, and
/// discovery failing is indistinguishable from discovery still running. The
/// hint is the only thing that tells those apart, so it is worth a test.
void main() {
  Widget wrap(Widget child) => FTheme(
    data: lightTheme,
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('offers something to check when no device turns up', (
    tester,
  ) async {
    final notifier = PresenceNotifier();

    await tester.pumpWidget(
      wrap(OnlineDevices(onTap: (_) {}, notifier: notifier)),
    );

    // Straight away it is just looking; suggesting a fix this early would be
    // noise on every cold start.
    expect(find.textContaining('Looking for nearby devices'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi network'), findsNothing);

    await tester.pump(const Duration(seconds: 9));

    expect(find.textContaining('same Wi-Fi network'), findsOneWidget);
    expect(
      find.textContaining('Looking for nearby devices'),
      findsOneWidget,
      reason: 'the hint adds to the spinner, it does not replace it',
    );

    // Both the notifier's sweep timer and the hint timer have to be gone
    // before the test ends, or the framework fails it for a pending timer.
    await tester.pumpWidget(const SizedBox());
    notifier.dispose();
  });
}
