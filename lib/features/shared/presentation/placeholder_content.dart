import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PlaceholderContent extends StatelessWidget {
  const PlaceholderContent({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });
  final String title;
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), backgroundColor: Colors.white),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFE4EFEB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 22),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
