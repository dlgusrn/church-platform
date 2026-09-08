import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/models/user.dart';
import 'membership_status_view.dart';

class ChurchCard extends StatelessWidget {
  const ChurchCard({
    super.key,
    required this.name,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.trailing,
  });

  final String name;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final selectable = enabled && onTap != null;
    final borderColor = selected ? AppColors.primary : AppColors.border;
    return Semantics(
      button: selectable,
      selected: selected,
      enabled: selectable,
      label: selected ? '$name, 현재 선택됨' : name,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: selectable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppRadii.control,
                  ),
                  child: const Icon(
                    Icons.church_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                  )
                else if (selectable)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MembershipStatusBadge extends StatelessWidget {
  const MembershipStatusBadge({super.key, required this.status});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '가입 상태: ${status.label}',
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: status.background,
        borderRadius: const BorderRadius.all(AppRadii.small),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
