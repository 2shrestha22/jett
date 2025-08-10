import 'package:anysend/widgets/custom_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PickerButtons extends StatefulWidget {
  const PickerButtons({super.key, required this.onPick});

  final void Function(List<PlatformFile> files) onPick;

  @override
  State<PickerButtons> createState() => _PickerButtonsState();
}

class _PickerButtonsState extends State<PickerButtons> {
  bool pickingFiles = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8.0),
      child: CustomButton(
        onPressed: () async {
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: true,
            type: FileType.any,
            onFileLoading: _onFileLoadHandler,
          );
          if (result != null && result.files.isNotEmpty) {
            widget.onPick(result.files);
          }
        },
        label: const Text('Pick Files'),
        icon: const Icon(LucideIcons.filePlus),
        isLoading: pickingFiles,
      ),
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
