import 'package:flutter/widgets.dart';

class AppSafeArea extends StatelessWidget {
  const AppSafeArea({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.extraBottom = 18,
  });

  final Widget child;
  final bool top;
  final bool bottom;
  final double extraBottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      minimum: EdgeInsets.only(bottom: bottom ? extraBottom : 0),
      child: child,
    );
  }
}
