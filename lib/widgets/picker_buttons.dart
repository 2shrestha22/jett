import 'dart:io';

import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/utils/io.dart';
import 'package:jett/widgets/drop_region.dart';

class PickerButton extends StatelessWidget {
  final void Function(List<Resource> resources) onResourceAdd;

  const PickerButton({super.key, required this.onResourceAdd});

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return desktop(context);
    } else {
      return mobile(context);
    }
  }

  Widget mobile(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        FButton(
          mainAxisSize: MainAxisSize.min,
          style: FButtonStyle.secondary(),
          onPress: () => _handleFilePick(onResourceAdd),
          prefix: Icon(FIcons.files),
          child: Text('Files'),
        ),
        if (Platform.isAndroid)
          FButton(
            mainAxisSize: MainAxisSize.min,
            style: FButtonStyle.secondary(),
            onPress: () => _handleApkPick(context, onResourceAdd),
            prefix: Icon(Icons.android),
            child: Text('APKs'),
          ),
      ],
    );
  }

  Widget desktop(BuildContext context) {
    final theme = context.theme;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FileDropRegion(
        onResourceAdd: (fileResource) => onResourceAdd([fileResource]),
        child: FButton.raw(
          onPress: () => _handleFilePick(onResourceAdd),
          child: Container(
            padding: EdgeInsets.all(8),
            width: double.infinity,
            height: 200,
            alignment: Alignment.center,
            decoration: theme.cardStyle.decoration.copyWith(
              color: theme.colors.primaryForeground,
            ),
            child: Column(
              spacing: 8,
              mainAxisSize: MainAxisSize.min,
              children: [
                FAvatar.raw(size: 60, child: Icon(FIcons.filePlus2, size: 30)),
                Text(
                  'Drag and drop or select files to share',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PickerButtonBar extends StatelessWidget {
  final void Function(List<Resource> resources) onResourceAdd;
  final void Function() onClear;

  const PickerButtonBar({
    super.key,
    required this.onResourceAdd,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 8,
        children:
            [
                  (() => _handleFilePick(onResourceAdd), FIcons.files),
                  if (Platform.isAndroid)
                    (
                      () => _handleApkPick(context, onResourceAdd),
                      Icons.android,
                    ),
                  (() => onClear(), FIcons.listX),
                ]
                .map(
                  (e) => FButton.icon(
                    style: FButtonStyle.secondary(),
                    onPress: e.$1,
                    child: Icon(e.$2, size: 24),
                  ),
                )
                .toList(),
      ),
    );
  }
}

Future<void> _handleApkPick(
  BuildContext context,
  void Function(List<Resource>) onResourceAdd,
) async {
  final apkResources = await context.push<List<Resource>>('/pick_apk');
  if (apkResources?.isEmpty ?? true) return;
  onResourceAdd(apkResources!);
}

Future<void> _handleFilePick(
  void Function(List<Resource>) onResourceAdd,
) async {
  final result = await FastFilePicker.pickMultipleFiles();

  if (result != null && result.isNotEmpty) {
    final resourceList = result.map((e) {
      if (e.uri != null) {
        return ContentResource(uri: e.uri!, name: e.name);
      }
      return FileResource(e.path!);
    }).toList();
    onResourceAdd(resourceList);
  }
}
