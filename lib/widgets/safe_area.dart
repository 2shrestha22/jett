import 'package:flutter/widgets.dart';

class FSafeArea extends SafeArea {
  const FSafeArea({
    super.key,
    super.bottom,
    super.left,
    super.maintainBottomViewPadding,
    super.minimum,
    super.right,
    super.top = false,
    required super.child,
  });
}
