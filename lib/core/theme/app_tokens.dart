import 'package:flutter/material.dart';

/// Canonical semantic visual language for church-platform.
abstract final class AppColors {
  static const primary = Color(0xFF315C52);
  static const primaryStrong = Color(0xFF142A25);
  static const primarySoft = Color(0xFFE4EFEB);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF5F7F6);
  static const border = Color(0xFFE1E7E4);
  static const divider = Color(0xFFE8ECEA);
  static const textPrimary = Color(0xFF17211E);
  static const textSecondary = Color(0xFF6D7774);
  static const textMuted = Color(0xFF8A9490);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFFDECEC);
  static const success = Color(0xFF25705D);
  static const successSoft = Color(0xFFE1F2EC);
  static const warning = Color(0xFF9B6814);
  static const warningSoft = Color(0xFFFFF2D8);
  static const disabled = Color(0xFFB7B1C1);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const pageHorizontal = 20.0;
  static const pageVertical = 24.0;
  static const sectionGap = 28.0;
  static const cardPadding = 20.0;
}

abstract final class AppRadii {
  static const small = Radius.circular(10);
  static const medium = Radius.circular(14);
  static const large = Radius.circular(20);
  static const card = BorderRadius.all(large);
  static const control = BorderRadius.all(medium);
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0D241C3D), blurRadius: 10, offset: Offset(0, 2)),
  ];
}
