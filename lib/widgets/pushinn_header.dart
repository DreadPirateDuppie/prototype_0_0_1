import 'package:flutter/material.dart';
import '../config/theme_config.dart';

class PushinnHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;

  const PushinnHeader({
    super.key,
    this.title = '> PUSHINN_',
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.bottom,
    this.backgroundColor = Colors.transparent,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: ThemeColors.matrixGreen,
          letterSpacing: 2,
          fontSize: 20,
          fontFamily: 'monospace',
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      elevation: 0,
      leading: leading,
      actions: actions,
      bottom: bottom,
    );
  }
}
