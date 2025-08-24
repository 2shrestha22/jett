import 'package:jett/model/resource.dart';
import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/widgets/button.dart';
import 'package:forui_assets/forui_assets.dart';

class MobilePickerButton extends StatelessWidget {
  final void Function(List<Resource> resources) onPick;

  const MobilePickerButton({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return FButton(
      mainAxisSize: MainAxisSize.min,
      onPress: () async {
        final result = await FastFilePicker.pickMultipleFiles();

        if (result != null && result.isNotEmpty) {
          final resourceList = result.map((e) {
            if (e.uri != null) {
              return ContentResource(uri: e.uri!, name: e.name);
            } else {
              return FileResource(e.path!);
            }
          }).toList();
          onPick(resourceList);
        }
      },
      prefix: Icon(FIcons.file),
      child: Text('Select Files'),
    );
  }
}
