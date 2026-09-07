import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// The five words both devices derive from each other's keys.
///
/// One widget rather than two copies, so the two screens being compared cannot
/// drift apart in spacing or font.
class VerificationWords extends StatelessWidget {
  final List<String> words;

  const VerificationWords(this.words, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        words.join('   '),
        textAlign: TextAlign.center,
        style: theme.typography.body.md.copyWith(
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
