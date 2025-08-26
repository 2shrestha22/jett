import 'package:jett/model/file_info.dart';
import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/widgets/button.dart';
import 'package:forui_assets/forui_assets.dart';

class MobilePickerButton extends StatelessWidget {
  final void Function(List<FileInfo> files) onPick;

  const MobilePickerButton({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return FButton(
      mainAxisSize: MainAxisSize.min,
      onPress: () async {
        final result = await FastFilePicker.pickMultipleFiles();

        if (result != null && result.isNotEmpty) {
          final fileInfoList = result
              .map((e) => FileInfo(name: e.name, path: e.path, uri: e.uri))
              .toList();
          onPick(fileInfoList);
        }
      },
      prefix: Icon(FIcons.file),
      child: Text('Select Files'),
    );
  }
}
