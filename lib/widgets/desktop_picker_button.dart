import 'package:anysend/model/file_info.dart';
import 'package:anysend/widgets/drop_region.dart';
import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class DesktopPickerButton extends StatelessWidget {
  final void Function(List<FileInfo> files) onFileAdd;

  // it is called multiple times when files are drag and dropped
  const DesktopPickerButton({super.key, required this.onFileAdd});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: FileDropRegion(
        onFileAdd: (fileInfo) {
          onFileAdd([fileInfo]);
        },
        child: FButton.raw(
          onPress: () async {
            final result = await FastFilePicker.pickMultipleFiles();

            if (result != null && result.isNotEmpty) {
              final fileInfoList = result
                  .map((e) => FileInfo(name: e.name, path: e.path, uri: e.uri))
                  .toList();
              onFileAdd(fileInfoList);
            }
          },
          child: Container(
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
                Text('Drag and drop or select files to share'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
