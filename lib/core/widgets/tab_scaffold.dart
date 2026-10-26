import 'package:flutter/material.dart';
import 'package:msu_wellbeing/core/widgets/help_button.dart';

/// Scaffold for a main tab: title, extra actions, and the [HelpButton],
/// which every main tab must show.
class TabScaffold extends StatelessWidget {
  const new({
    required this.title,
    required this.body,
    this.actions = const [],
    this.titleWidget,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  /// Replaces the plain [title] text when provided.
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: titleWidget ?? Text(title),
        actions: [const HelpButton(), ...actions],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}
