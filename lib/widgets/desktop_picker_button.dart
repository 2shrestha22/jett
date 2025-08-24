import 'package:jett/model/resource.dart';
import 'package:jett/widgets/drop_region.dart';
import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class DesktopPickerButton extends StatelessWidget {
  final void Function(List<Resource> resources) onResourceAdd;

  // it is called multiple times when files are drag and dropped
  const DesktopPickerButton({super.key, required this.onResourceAdd});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FileDropRegion(
        onResourceAdd: (fileResource) {
          onResourceAdd([fileResource]);
        },
        child: FButton.raw(
          onPress: () async {
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
          },
          child: Container(
            padding: EdgeInsets.all(8),
            width: double.infinity,
            height: 200,
            alignment: Alignment.center,
            decoration: context.theme.cardStyle.decoration.copyWith(
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
