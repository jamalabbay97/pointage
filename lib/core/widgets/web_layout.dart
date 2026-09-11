import 'package:flutter/material.dart';

/// Wraps [child] in a horizontally-centred, max-width box on wide viewports
/// (web / desktop) while leaving mobile layouts unchanged.
///
/// Usage – replace a screen's `body:` content with:
/// ```dart
/// body: WebLayout(child: ListView(...))
/// ```
class WebLayout extends StatelessWidget {
  const WebLayout({
    super.key,
    required this.child,
    this.maxWidth = 680,
  });

  final Widget child;

  /// Maximum body width in logical pixels. Defaults to 680 px which fits
  /// comfortably in a typical browser window and looks balanced on desktop.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth <= maxWidth) return child;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
