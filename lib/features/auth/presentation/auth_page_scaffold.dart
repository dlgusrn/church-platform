import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Shared responsive shell for the two authentication forms.
class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.pageHorizontal,
      AppSpacing.pageVertical,
      AppSpacing.pageHorizontal,
      32,
    ),
  });

  final PreferredSizeWidget? appBar;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    body: SafeArea(
      top: appBar == null,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    ),
  );
}
