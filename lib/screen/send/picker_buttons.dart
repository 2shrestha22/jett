import 'package:anysend/model/file_info.dart';
import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class PickerButtons extends StatefulWidget {
  const PickerButtons({super.key, required this.onPick});

  final void Function(List<FileInfo> files) onPick;

  @override
  State<PickerButtons> createState() => _PickerButtonsState();
}

class _PickerButtonsState extends State<PickerButtons> {
  bool pickingFiles = false;

  @override
  Widget build(BuildContext context) {
    return FButton(
      mainAxisSize: MainAxisSize.min,
      style: FButtonStyle.outline(),
      onPress: pickingFiles
          ? null
          : () async {
              final result = await FastFilePicker.pickMultipleFiles();

              if (result != null && result.isNotEmpty) {
                final fileInfo = result
                    .map(
                      (e) => FileInfo(name: e.name, path: e.path, uri: e.uri),
                    )
                    .toList();
                widget.onPick(fileInfo);
              }
              // final result = await FilePicker.platform.pickFiles(
              //   allowMultiple: true,
              //   type: FileType.any,
              //   onFileLoading: _onFileLoadHandler,
              //   withReadStream: true,
              // );
              // if (result != null && result.files.isNotEmpty) {
              //   widget.onPick(result.files);
              // }
            },

      prefix: pickingFiles ? FProgress.circularIcon() : Icon(FIcons.filePlus),
      child: Text('Select Files'),
    );
  }

  _onFileLoadHandler(status) {
    switch (status) {
      case FilePickerStatus.picking:
        setState(() {
          pickingFiles = true;
        });
        break;
      case FilePickerStatus.done:
        setState(() {
          pickingFiles = false;
        });
        break;
    }
  }
}
