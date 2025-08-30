import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:jett/messages.g.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/platform/platform_api.dart';

class ApkScreen extends StatefulWidget {
  const ApkScreen({super.key});

  @override
  State<ApkScreen> createState() => _ApkScreenState();
}

class _ApkScreenState extends State<ApkScreen> {
  final _api = PlatformApi.instance;
  bool isSystemAppVisible = false;

  List<APKInfo> selectedAPKs = [];
  late final Future<List<APKInfo>> future;

  @override
  void initState() {
    super.initState();
    future = _api.getAPKs();
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Text("Select APKs"),
        suffixes: [
          FButton.icon(
            onPress: () {
              Navigator.of(context).pop();
            },
            child: Icon(FIcons.x),
          ),
        ],
      ),
      child: SafeArea(
        child: FutureBuilder(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final filteredAPKs = _filterList(snapshot);
              return Column(
                spacing: 8,
                children: [
                  Expanded(
                    child: ListView.separated(
                      separatorBuilder: (context, index) => SizedBox(height: 8),
                      itemCount: filteredAPKs.length,
                      itemBuilder: (context, index) {
                        final item = filteredAPKs.elementAt(index);
                        final selected = selectedAPKs.contains(item);
                        return FTile(
                          selected: selected,
                          suffix: selected
                              ? Icon(FIcons.check)
                              : SizedBox.shrink(),
                          prefix: SizedBox.square(
                            dimension: 40,
                            child: Image.memory(item.icon),
                          ),
                          title: Row(
                            spacing: 4,
                            children: [
                              Text(item.name),
                              if (item.isSystemApp) Icon(FIcons.cpu, size: 12),
                              if (item.isSplitApk) Icon(FIcons.split, size: 12),
                            ],
                          ),
                          subtitle: Text(item.packageName),
                          onPress: () => _onPress(item),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      spacing: 8,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: FButton(
                            style: FButtonStyle.outline(),
                            prefix: isSystemAppVisible
                                ? Icon(FIcons.eye)
                                : Icon(FIcons.eyeOff),
                            child: isSystemAppVisible
                                ? Text('Hide System Apps')
                                : Text('Show System Apps'),
                            onPress: () {
                              setState(() {
                                isSystemAppVisible = !isSystemAppVisible;
                              });
                            },
                          ),
                        ),
                        FButton(
                          prefix: Icon(FIcons.plus),
                          style: FButtonStyle.primary(),
                          suffix: Text(
                            '(${selectedAPKs.length})',
                            style: TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          onPress: selectedAPKs.isEmpty ? null : _onAddPress,
                          child: Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            if (snapshot.hasError) {
              return Text(snapshot.error.toString());
            }
            return FProgress.circularIcon();
          },
        ),
      ),
    );
  }

  void _onPress(APKInfo item) {
    setState(() {
      if (selectedAPKs.contains(item)) {
        selectedAPKs.remove(item);
      } else {
        selectedAPKs.add(item);
      }
    });
  }

  List<APKInfo> _filterList(AsyncSnapshot<List<APKInfo>> snapshot) {
    return snapshot.data!
        .where((element) => !element.isSystemApp || isSystemAppVisible)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _onAddPress() {
    Navigator.pop(
      context,
      selectedAPKs
          .map((e) => ContentResource(uri: e.contentUri, name: '${e.name}.apk'))
          .toList(),
    );
  }
}
