import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/models/user.dart';

extension MembershipStatusView on MembershipStatus {
  String get label => switch (this) {
    MembershipStatus.pending => '승인 대기',
    MembershipStatus.approved => '승인 완료',
    MembershipStatus.rejected => '가입 거절',
  };

  Color get color => switch (this) {
    MembershipStatus.pending => AppColors.warning,
    MembershipStatus.approved => AppColors.success,
    MembershipStatus.rejected => AppColors.danger,
  };

  Color get background => switch (this) {
    MembershipStatus.pending => AppColors.warningSoft,
    MembershipStatus.approved => AppColors.successSoft,
    MembershipStatus.rejected => AppColors.dangerSoft,
  };
}
