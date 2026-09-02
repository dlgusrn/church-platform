import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/home_models.dart';

class LiveBroadcastAdminScreen extends StatefulWidget {
  const LiveBroadcastAdminScreen({super.key});

  @override
  State<LiveBroadcastAdminScreen> createState() =>
      _LiveBroadcastAdminScreenState();
}

class _LiveBroadcastAdminScreenState extends State<LiveBroadcastAdminScreen> {
  late Future<List<LiveBroadcast>> _items;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _items = AppScope.of(context).loadManagedLiveBroadcasts();
  }

  void _reload() {
    final items = AppScope.of(context).loadManagedLiveBroadcasts();
    if (!mounted) return;
    setState(() {
      _items = items;
    });
  }

  Future<void> _edit([LiveBroadcast? broadcast]) async {
    final state = AppScope.of(context);
    final draft = await showDialog<LiveBroadcastDraft>(
      context: context,
      builder: (_) => _LiveDialog(broadcast: broadcast),
    );
    if (draft == null || !mounted) return;
    try {
      await state.saveLiveBroadcast(draft, broadcastId: broadcast?.id);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LIVE 방송 관리')),
    floatingActionButton: FloatingActionButton(
      onPressed: _edit,
      child: const Icon(Icons.add),
    ),
    body: FutureBuilder<List<LiveBroadcast>>(
      future: _items,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty)
          return const Center(child: Text('등록된 LIVE 방송이 없습니다.'));
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                onTap: () => _edit(item),
                title: Text(item.displayTitle),
                subtitle: Text(
                  '${_date(item.broadcastDate)} · ${item.youtubeUrl}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _statusLabel(item.status),
                  style: const TextStyle(color: AppTheme.primary),
                ),
              ),
            );
          },
        );
      },
    ),
  );

  static String _date(DateTime value) =>
      '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';
}

class _LiveDialog extends StatefulWidget {
  const _LiveDialog({this.broadcast});
  final LiveBroadcast? broadcast;

  @override
  State<_LiveDialog> createState() => _LiveDialogState();
}

class _LiveDialogState extends State<_LiveDialog> {
  late final TextEditingController _title;
  late final TextEditingController _url;
  late DateTime _date;
  late LiveWorshipType _worshipType;
  late final TextEditingController _customWorshipName;
  late LiveBroadcastStatus _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.broadcast;
    _title = TextEditingController(text: item?.titleOverride ?? '');
    _url = TextEditingController(text: item?.youtubeUrl ?? '');
    _date = item?.broadcastDate ?? DateTime.now();
    _worshipType = item?.worshipType ?? LiveWorshipType.special;
    _customWorshipName = TextEditingController(
      text: item?.customWorshipName ?? '',
    );
    _status = item?.status ?? LiveBroadcastStatus.scheduled;
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _customWorshipName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.broadcast == null ? 'LIVE 등록' : 'LIVE 수정'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('방송 날짜'),
            trailing: Text(_LiveBroadcastAdminScreenState._date(_date)),
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (selected != null) setState(() => _date = selected);
            },
          ),
          DropdownButtonFormField<LiveWorshipType>(
            initialValue: _worshipType,
            decoration: const InputDecoration(labelText: '예배 유형'),
            items: LiveWorshipType.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => _worshipType = value!),
          ),
          const SizedBox(height: 12),
          if (_worshipType == LiveWorshipType.custom) ...[
            TextField(
              controller: _customWorshipName,
              decoration: const InputDecoration(labelText: '사용자 지정 예배명'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: '제목 직접 지정 (선택)',
              helperText: '비워두면 서버에서 날짜와 예배 유형으로 생성합니다.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'YouTube URL'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LiveBroadcastStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: '상태'),
            items: LiveBroadcastStatus.values
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(_statusLabel(item)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _status = value!),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () {
          if (_url.text.trim().isEmpty ||
              (_worshipType == LiveWorshipType.custom &&
                  _customWorshipName.text.trim().isEmpty)) {
            setState(() => _error = 'YouTube URL과 사용자 지정 예배명을 확인해주세요.');
            return;
          }
          Navigator.pop(
            context,
            LiveBroadcastDraft(
              worshipType: _worshipType,
              customWorshipName: _worshipType == LiveWorshipType.custom
                  ? _customWorshipName.text.trim()
                  : null,
              broadcastDate: _date,
              titleOverride: _title.text.trim().isEmpty
                  ? null
                  : _title.text.trim(),
              youtubeUrl: _url.text.trim(),
              status: _status,
            ),
          );
        },
        child: const Text('저장'),
      ),
    ],
  );
}

String _statusLabel(LiveBroadcastStatus status) => switch (status) {
  LiveBroadcastStatus.scheduled => '예정',
  LiveBroadcastStatus.live => '방송 중',
  LiveBroadcastStatus.ended => '종료',
};
