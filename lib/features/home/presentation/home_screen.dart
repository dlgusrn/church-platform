import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/overflow_only_scroll_physics.dart';
import '../../live/presentation/live_entry.dart';
import '../../notices/domain/notice_models.dart';
import '../../notices/presentation/notice_detail_screen.dart';
import '../../notices/presentation/notices_screen.dart';
import '../domain/home_models.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final content = state.homeContent;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const OverflowOnlyScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.md,
                AppSpacing.pageHorizontal,
                36,
              ),
              sliver: SliverList.list(
                children: [
                  _HomeHeader(
                    churchName: state.currentChurchMembership!.church.name,
                    canSwitch: state.approvedMemberships.length > 1,
                    onSwitch: state.requestChurchSelection,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (state.homeError != null)
                    _HomeError(onRetry: state.reloadHome)
                  else if (content == null)
                    const _HomeLoading()
                  else ...[
                    if (content.live case final live? when live.isLive)
                      LiveCard(
                        live: live,
                        onTap: () => LiveEntry.open(context, live),
                      )
                    else
                      const LiveEmptyCard(),
                    const SizedBox(height: AppSpacing.sectionGap),
                    WorshipScheduleCard(schedules: content.orderedSchedules),
                    if (state.has(AppPermission.noticeView)) ...[
                      const SizedBox(height: AppSpacing.sectionGap),
                      RecentNoticesSection(notices: state.homeNotices),
                    ],
                    if (state.has(AppPermission.vodView)) ...[
                      const SizedBox(height: AppSpacing.sectionGap),
                      RecentVideosSection(videos: content.recentVideos),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.churchName,
    required this.canSwitch,
    required this.onSwitch,
  });

  final String churchName;
  final bool canSwitch;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('현재 소속 교회', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          churchName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
    if (!canSwitch) return title;
    return Semantics(
      button: true,
      label: '$churchName 교회 전환',
      child: InkWell(
        borderRadius: const BorderRadius.all(AppRadii.small),
        onTap: onSwitch,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(child: title),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) action!,
    ],
  );
}

class LiveCard extends StatelessWidget {
  const LiveCard({super.key, required this.live, required this.onTap});

  final LiveBroadcast live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'LIVE 방송 ${live.title} 재생',
    child: Material(
      color: AppColors.primaryStrong,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.75,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryStrong],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -12,
                    top: 18,
                    child: Icon(
                      Icons.church_outlined,
                      size: 148,
                      color: AppColors.primarySoft.withValues(alpha: 0.16),
                    ),
                  ),
                  const Center(
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.surface,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.primary,
                        size: 38,
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.lg,
                    top: AppSpacing.lg,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.all(AppRadii.small),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          live.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textOnPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (live.worshipLabel.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            live.worshipLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primarySoft,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textOnPrimary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LiveEmptyCard extends StatelessWidget {
  const LiveEmptyCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 136,
    decoration: const BoxDecoration(
      color: AppColors.primaryStrong,
      borderRadius: AppRadii.card,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryStrong],
      ),
    ),
    alignment: Alignment.center,
    child: const Text(
      '지금은\n예배시간이 아닙니다 :)',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.textOnPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.45,
      ),
    ),
  );
}

class WorshipScheduleCard extends StatelessWidget {
  const WorshipScheduleCard({super.key, required this.schedules});

  final List<WorshipSchedule> schedules;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 9),
              Text('예배시간 안내', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 18),
          if (schedules.isEmpty)
            const Text(
              '등록된 예배 일정이 없습니다.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (var index = 0; index < schedules.length; index++) ...[
              _WorshipScheduleRow(schedule: schedules[index]),
              if (index < schedules.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: Divider(height: 1),
                ),
            ],
        ],
      ),
    ),
  );
}

class _WorshipScheduleRow extends StatelessWidget {
  const _WorshipScheduleRow({required this.schedule});

  final WorshipSchedule schedule;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          '${schedule.dayLabel} · ${schedule.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        schedule.displayTime,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class RecentNoticesSection extends StatelessWidget {
  const RecentNoticesSection({super.key, required this.notices});

  final List<Notice>? notices;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      HomeSectionHeader(
        title: '최근 공지사항',
        action: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NoticesScreen()),
          ),
          child: const Text('전체보기'),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (notices == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        )
      else if (notices!.isEmpty)
        const _SectionEmptyState(message: '등록된 공지사항이 없습니다.')
      else
        Card(
          child: Column(
            children: [
              for (var index = 0; index < notices!.take(3).length; index++) ...[
                _NoticeItem(notice: notices![index]),
                if (index < notices!.take(3).length - 1)
                  const Divider(height: 1),
              ],
            ],
          ),
        ),
    ],
  );
}

class _NoticeItem extends StatelessWidget {
  const _NoticeItem({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoticeDetailScreen(noticeId: notice.id),
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xs,
    ),
    leading: notice.isPinned
        ? const Icon(
            Icons.push_pin_outlined,
            size: 20,
            color: AppColors.primary,
          )
        : null,
    title: Text(notice.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      notice.isPinned ? '고정 · ${notice.listDate}' : notice.listDate,
    ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.textSecondary,
    ),
  );
}

class RecentVideosSection extends StatelessWidget {
  const RecentVideosSection({super.key, required this.videos});

  final List<RecentVideo> videos;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const HomeSectionHeader(title: '최근 영상'),
      const SizedBox(height: AppSpacing.sm),
      if (videos.isEmpty)
        const _SectionEmptyState(message: '등록된 최근 영상이 없습니다.')
      else
        Card(
          child: Column(
            children: [
              for (var index = 0; index < videos.length; index++) ...[
                RecentVideoItem(video: videos[index]),
                if (index < videos.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
    ],
  );
}

class RecentVideoItem extends StatelessWidget {
  const RecentVideoItem({super.key, required this.video});

  final RecentVideo video;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Row(
      children: [
        Container(
          width: 96,
          height: 60,
          decoration: const BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.all(AppRadii.small),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: AppColors.primary,
            size: 30,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${video.publishedAt.year}.${video.publishedAt.month.toString().padLeft(2, '0')}.${video.publishedAt.day.toString().padLeft(2, '0')} · ${video.duration}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 240,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.md),
        Text(
          '홈 정보를 불러오지 못했습니다.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    ),
  );
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surfaceMuted,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    ),
  );
}
