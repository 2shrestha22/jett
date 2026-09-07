import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:jett/adaptive_dialog.dart';
import 'package:jett/widgets/dialogs/verification_words.dart';

/// Asks whether the peer's screen shows the same words as this one.
///
/// Presentation only; the caller closes it if the session ends first.
///
/// Returns true to send, false to refuse, null if it was dismissed.
Future<bool?> showVerifyDeviceDialog(
  BuildContext context, {
  required String peerName,
  required List<String> words,
}) {
  return showFDialog<bool>(
    context: context,
    builder: (context, _, _) {
      final theme = context.theme;
      return AdaptiveDialog(
        title: const Text('Verify device'),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            // Names the device so the person knows which screen to compare
            // against.
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(text: 'Does '),
                  TextSpan(
                    text: peerName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' show these same words?'),
                ],
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
            VerificationWords(words),
          ],
        ),
        actions: [
          FButton(
            variant: .secondary,
            onPress: () => Navigator.pop(context, false),
            child: const Text("Doesn't match"),
          ),
          FButton(
            variant: .primary,
            onPress: () => Navigator.pop(context, true),
            child: const Text('Yes, send'),
          ),
        ],
      );
    },
  );
}
