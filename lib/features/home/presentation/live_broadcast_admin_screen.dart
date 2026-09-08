import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_tokens.dart';
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

  Future<void> _openEditor([LiveBroadcast? broadcast]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LiveBroadcastEditorScreen(broadcast: broadcast),
      ),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = AppScope.of(context).has(AppPermission.liveManage);
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE 방송 관리'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'LIVE 방송 등록',
              onPressed: _openEditor,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: !canManage
          ? const _LiveUnavailable(message: 'LIVE 방송을 관리할 권한이 없습니다.')
          : FutureBuilder<List<LiveBroadcast>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _LiveUnavailable(
                    message: 'LIVE 방송을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) return const _LiveEmpty();
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
                    child: _LiveBroadcastRow(
                      broadcast: items[index],
                      onTap: () => _openEditor(items[index]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class LiveBroadcastEditorScreen extends StatefulWidget {
  const LiveBroadcastEditorScreen({super.key, this.broadcast});

  final LiveBroadcast? broadcast;

  @override
  State<LiveBroadcastEditorScreen> createState() =>
      _LiveBroadcastEditorScreenState();
}

class _LiveBroadcastEditorScreenState extends State<LiveBroadcastEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _url;
  late final TextEditingController _customWorshipName;
  late DateTime _date;
  late LiveWorshipType _worshipType;
  late LiveBroadcastStatus _status;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final broadcast = widget.broadcast;
    _title = TextEditingController(text: broadcast?.titleOverride ?? '');
    _url = TextEditingController(text: broadcast?.youtubeUrl ?? '');
    _customWorshipName = TextEditingController(
      text: broadcast?.customWorshipName ?? '',
    );
    _date = broadcast?.broadcastDate ?? DateTime.now();
    _worshipType = broadcast?.worshipType ?? LiveWorshipType.special;
    _status = broadcast?.status ?? LiveBroadcastStatus.scheduled;
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _customWorshipName.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_url.text.trim().isEmpty ||
        (_worshipType == LiveWorshipType.custom &&
            _customWorshipName.text.trim().isEmpty)) {
      setState(
        () => _error = _worshipType == LiveWorshipType.custom
            ? 'YouTube URL과 사용자 지정 예배명을 입력해주세요.'
            : 'YouTube URL을 입력해주세요.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppScope.of(context).saveLiveBroadcast(
        LiveBroadcastDraft(
          worshipType: _worshipType,
          customWorshipName: _worshipType == LiveWorshipType.custom
              ? _customWorshipName.text.trim()
              : null,
          broadcastDate: _date,
          titleOverride: _title.text.trim().isEmpty ? null : _title.text.trim(),
          youtubeUrl: _url.text.trim(),
          status: _status,
        ),
        broadcastId: widget.broadcast?.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했습니다. 입력 내용을 확인해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.broadcast == null ? 'LIVE 방송 등록' : 'LIVE 방송 수정'),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.pageVertical,
          AppSpacing.pageHorizontal,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _LiveFieldLabel('방송 날짜'),
            Card(
              child: ListTile(
                enabled: !_saving,
                title: Text(_dateLabel(_date)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _LiveFieldLabel('예배 유형'),
            DropdownButtonFormField<LiveWorshipType>(
              initialValue: _worshipType,
              items: LiveWorshipType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _worshipType = value!),
            ),
            if (_worshipType == LiveWorshipType.custom) ...[
              const SizedBox(height: AppSpacing.lg),
              const _LiveFieldLabel('사용자 지정 예배명'),
              TextField(
                controller: _customWorshipName,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: '예배명을 입력하세요'),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const _LiveFieldLabel('방송 제목 (선택)'),
            TextField(
              controller: _title,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '입력하지 않으면 예배 유형에 맞는 제목이 표시됩니다.',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _LiveFieldLabel('YouTube URL'),
            TextField(
              controller: _url,
              enabled: !_saving,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'https://www.youtube.com/...',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _LiveFieldLabel('상태'),
            DropdownButtonFormField<LiveBroadcastStatus>(
              initialValue: _status,
              items: LiveBroadcastStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _status = value!),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _LiveFormError(message: _error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const _LiveButtonProgress() : const Text('저장'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LiveBroadcastRow extends StatelessWidget {
  const _LiveBroadcastRow({required this.broadcast, required this.onTap});

  final LiveBroadcast broadcast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: onTap,
      title: Text(
        broadcast.displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          '${_dateLabel(broadcast.broadcastDate)} · ${broadcast.worshipLabel}\n영상 링크 등록됨',
        ),
      ),
      isThreeLine: true,
      trailing: _LiveStatusBadge(status: broadcast.status),
    ),
  );
}

class _LiveStatusBadge extends StatelessWidget {
  const _LiveStatusBadge({required this.status});

  final LiveBroadcastStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      LiveBroadcastStatus.scheduled => (
        AppColors.warningSoft,
        AppColors.warning,
      ),
      LiveBroadcastStatus.live => (AppColors.dangerSoft, AppColors.danger),
      LiveBroadcastStatus.ended => (
        AppColors.surfaceMuted,
        AppColors.textSecondary,
      ),
    };
    return Semantics(
      label: _statusLabel(status),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: AppRadii.control,
        ),
        child: Text(
          _statusLabel(status),
          style: TextStyle(
            color: colors.$2,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LiveEmpty extends StatelessWidget {
  const _LiveEmpty();

  @override
  Widget build(BuildContext context) => const _LiveUnavailable(
    icon: Icons.live_tv_outlined,
    message: '등록된 LIVE 방송이 없습니다.',
  );
}

class _LiveUnavailable extends StatelessWidget {
  const _LiveUnavailable({required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 36, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

class _LiveFieldLabel extends StatelessWidget {
  const _LiveFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _LiveFormError extends StatelessWidget {
  const _LiveFormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.all(AppRadii.small),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.danger),
      ),
    ),
  );
}

class _LiveButtonProgress extends StatelessWidget {
  const _LiveButtonProgress();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: AppColors.textOnPrimary,
    ),
  );
}

String _dateLabel(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

String _statusLabel(LiveBroadcastStatus status) => switch (status) {
  LiveBroadcastStatus.scheduled => '예정',
  LiveBroadcastStatus.live => '방송 중',
  LiveBroadcastStatus.ended => '종료',
};
