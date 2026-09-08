import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/notice_models.dart';
import 'notice_detail_screen.dart';
import 'notice_editor_screen.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  late Future<List<Notice>> _items;
  bool _loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _items = AppScope.of(context).loadNotices();
  }

  void _reload() {
    final future = AppScope.of(context).loadNotices();
    if (!mounted) return;
    setState(() {
      _items = future;
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<Notice>(
      MaterialPageRoute(builder: (_) => const NoticeEditorScreen()),
    );
    if (created != null) _reload();
  }

  Future<void> _openDetail(Notice notice) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoticeDetailScreen(noticeId: notice.id),
      ),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항'),
        actions: [
          if (state.has(AppPermission.noticeCreate))
            IconButton(
              tooltip: '공지 작성',
              onPressed: _openCreate,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: FutureBuilder<List<Notice>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const _NoticeListError();
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const _NoticeListEmpty();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.pageVertical,
              AppSpacing.pageHorizontal,
              32,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == items.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: _NoticeListItem(
                notice: items[index],
                onTap: () => _openDetail(items[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoticeListItem extends StatelessWidget {
  const _NoticeListItem({required this.notice, required this.onTap});

  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Semantics(
      button: true,
      label: notice.isPinned ? '고정 공지 ${notice.title}' : notice.title,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        title: Text(
          notice.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Row(
            children: [
              if (notice.isPinned) ...[
                const Icon(
                  Icons.push_pin_outlined,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '고정',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(child: Text(notice.listDate)),
            ],
          ),
        ),
        trailing: const ExcludeSemantics(
          child: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ),
      ),
    ),
  );
}

class _NoticeListEmpty extends StatelessWidget {
  const _NoticeListEmpty();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.campaign_outlined,
            size: 36,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('공지사항이 없습니다.', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '새로운 소식이 등록되면 이곳에서 확인할 수 있습니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

class _NoticeListError extends StatelessWidget {
  const _NoticeListError();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(
        '공지사항을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
