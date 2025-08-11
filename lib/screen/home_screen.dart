import 'package:anysend/discovery/konst.dart';
import 'package:anysend/screen/receive_screen.dart';
import 'package:anysend/screen/send_screen.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  final navigationItems = [
    ('Receive', FIcons.wifi),
    ('Send', FIcons.send),
    ('Settings', FIcons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final breakpoints = context.theme.breakpoints;
    final width = MediaQuery.sizeOf(context).width;
    final isLargeScreen = width > breakpoints.sm;

    return FScaffold(
      header: isLargeScreen ? null : FHeader(title: Text(appName)),
      // childPad: true,
      sidebar: isLargeScreen
          ? FSidebar(
              style: (style) =>
                  style.copyWith(constraints: BoxConstraints(maxWidth: 200)),
              header: FHeader(title: Text(appName)),
              children: [
                FSidebarGroup(
                  children: navigationItems.indexed
                      .map(
                        (e) => FSidebarItem(
                          icon: Icon(e.$2.$2),
                          label: Text(e.$2.$1),
                          selected: index == e.$1,
                          onPress: () {
                            setState(() {
                              index = e.$1;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
            )
          : null,
      footer: isLargeScreen
          ? null
          : FBottomNavigationBar(
              index: index,
              onChange: (index) {
                setState(() => this.index = index);
              },
              children: [
                FBottomNavigationBarItem(
                  icon: Icon(FIcons.wifi),
                  label: const Text('Receive'),
                ),
                FBottomNavigationBarItem(
                  icon: Icon(FIcons.send),
                  label: const Text('Send'),
                ),
                FBottomNavigationBarItem(
                  icon: Icon(FIcons.settings),
                  label: const Text('Settings'),
                ),
              ],
            ),

      child: [ReceiveScreen(), SendScreen(), Placeholder()][index],
    );
  }
}
