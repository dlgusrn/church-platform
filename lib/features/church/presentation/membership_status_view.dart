import 'package:flutter/material.dart';

import '../../../shared/models/user.dart';

extension MembershipStatusView on MembershipStatus {
  String get label => switch (this) {
    MembershipStatus.pending => '승인 대기',
    MembershipStatus.approved => '승인 완료',
    MembershipStatus.rejected => '가입 거절',
  };

  Color get color => switch (this) {
    MembershipStatus.pending => const Color(0xFF9B6814),
    MembershipStatus.approved => const Color(0xFF25705D),
    MembershipStatus.rejected => const Color(0xFFB04444),
  };

  Color get background => switch (this) {
    MembershipStatus.pending => const Color(0xFFFFF2D8),
    MembershipStatus.approved => const Color(0xFFE1F2EC),
    MembershipStatus.rejected => const Color(0xFFFFE8E8),
  };
}
