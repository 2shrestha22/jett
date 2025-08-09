import 'package:anysend/widgets/loader.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
  });

  final VoidCallback? onPressed;
  final Widget label;
  final bool isLoading;
  final bool isDisabled;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: !(isDisabled || isLoading) ? onPressed : null,
      label: label,
      icon: AnimatedSwitcher(
        duration: Durations.medium4,
        child: isLoading ? const Loader() : icon,
      ),
    );
  }
}
