import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_theme.dart';
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
      appBar: AppBar(title: const Text('공지사항')),
      floatingActionButton: state.has(AppPermission.noticeCreate)
          ? FloatingActionButton(
              onPressed: _openCreate,
              child: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<List<Notice>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty)
            return const Center(child: Text('등록된 공지사항이 없습니다.'));
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  onTap: () => _openDetail(item),
                  leading: item.isPinned
                      ? const Icon(
                          Icons.push_pin_rounded,
                          color: AppTheme.primary,
                        )
                      : null,
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(item.listDate),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
