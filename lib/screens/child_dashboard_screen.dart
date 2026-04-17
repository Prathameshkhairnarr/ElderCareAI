import 'package:flutter/material.dart';
import 'child_dashboard/child_main_screen.dart';

// This file is kept to not break existing routing logic.
// It simply forwards the user to the newly architected ChildMainScreen.
class ChildDashboardScreen extends StatelessWidget {
  const ChildDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ChildMainScreen();
  }
}
