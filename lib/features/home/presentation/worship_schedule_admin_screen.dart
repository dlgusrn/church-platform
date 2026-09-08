import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/permission/app_permission.dart';
import '../../../core/theme/app_tokens.dart';
import '../domain/home_models.dart';

class WorshipScheduleAdminScreen extends StatefulWidget {
  const WorshipScheduleAdminScreen({super.key});

  @override
  State<WorshipScheduleAdminScreen> createState() =>
      _WorshipScheduleAdminScreenState();
}

class _WorshipScheduleAdminScreenState
    extends State<WorshipScheduleAdminScreen> {
  late Future<List<WorshipSchedule>> _items;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _items = AppScope.of(context).loadManagedWorshipSchedules();
  }

  void _reload() {
    final items = AppScope.of(context).loadManagedWorshipSchedules();
    if (!mounted) return;
    setState(() {
      _items = items;
    });
  }

  Future<void> _openEditor([WorshipSchedule? schedule]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorshipScheduleEditorScreen(schedule: schedule),
      ),
    );
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = AppScope.of(context).has(AppPermission.scheduleManage);
    return Scaffold(
      appBar: AppBar(
        title: const Text('예배시간 관리'),
        actions: [
          if (canManage)
            IconButton(
              tooltip: '예배시간 등록',
              onPressed: _openEditor,
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: !canManage
          ? const _AdminUnavailable(message: '예배시간을 관리할 권한이 없습니다.')
          : FutureBuilder<List<WorshipSchedule>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _AdminUnavailable(
                    message: '예배시간을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) return const _WorshipEmpty();
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
                    child: _WorshipScheduleRow(
                      schedule: items[index],
                      onTap: () => _openEditor(items[index]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class WorshipScheduleEditorScreen extends StatefulWidget {
  const WorshipScheduleEditorScreen({super.key, this.schedule});

  final WorshipSchedule? schedule;

  @override
  State<WorshipScheduleEditorScreen> createState() =>
      _WorshipScheduleEditorScreenState();
}

class _WorshipScheduleEditorScreenState
    extends State<WorshipScheduleEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _dayLabel;
  late final TextEditingController _order;
  late TimeOfDay _time;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _title = TextEditingController(text: schedule?.title ?? '');
    _dayLabel = TextEditingController(text: schedule?.dayLabel ?? '');
    _order = TextEditingController(text: '${schedule?.displayOrder ?? 0}');
    final parts = schedule?.time.split(':');
    _time = parts == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    _isActive = schedule?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _dayLabel.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) setState(() => _time = selected);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty || _dayLabel.text.trim().isEmpty) {
      setState(() => _error = '예배명과 요일 안내를 입력해주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppScope.of(context).saveWorshipSchedule(
        WorshipScheduleDraft(
          title: _title.text.trim(),
          dayLabel: _dayLabel.text.trim(),
          time:
              '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00',
          displayOrder: int.tryParse(_order.text) ?? 0,
          isActive: _isActive,
        ),
        scheduleId: widget.schedule?.id,
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
      title: Text(widget.schedule == null ? '예배시간 등록' : '예배시간 수정'),
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
            const _FieldLabel('예배명'),
            TextField(
              controller: _title,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '예배명을 입력하세요'),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _FieldLabel('요일/안내 문구'),
            TextField(
              controller: _dayLabel,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '예: 주일 오전'),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _FieldLabel('시작 시간'),
            Card(
              child: ListTile(
                enabled: !_saving,
                title: Text(_time.format(context)),
                trailing: const Icon(Icons.schedule_outlined),
                onTap: _pickTime,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _FieldLabel('표시 순서'),
            TextField(
              controller: _order,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                helperText: '숫자가 작을수록 먼저 표시됩니다.',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Card(
              color: AppColors.surfaceMuted,
              child: SwitchListTile(
                title: const Text('활성화'),
                subtitle: const Text('활성화된 예배시간만 일반 사용자에게 표시됩니다.'),
                value: _isActive,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isActive = value),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _FormError(message: _error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const _ButtonProgress() : const Text('저장'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorshipScheduleRow extends StatelessWidget {
  const _WorshipScheduleRow({required this.schedule, required this.onTap});

  final WorshipSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      onTap: onTap,
      title: Text(
        schedule.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text('${schedule.dayLabel} · ${schedule.displayTime}'),
      ),
      trailing: _ScheduleStatusBadge(isActive: schedule.isActive),
    ),
  );
}

class _ScheduleStatusBadge extends StatelessWidget {
  const _ScheduleStatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) => Semantics(
    label: isActive ? '활성' : '비활성',
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successSoft : AppColors.surfaceMuted,
        borderRadius: AppRadii.control,
      ),
      child: Text(
        isActive ? '활성' : '비활성',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _WorshipEmpty extends StatelessWidget {
  const _WorshipEmpty();

  @override
  Widget build(BuildContext context) => const _AdminUnavailable(
    icon: Icons.event_note_outlined,
    message: '등록된 예배시간이 없습니다.',
  );
}

class _AdminUnavailable extends StatelessWidget {
  const _AdminUnavailable({required this.message, this.icon});

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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});

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

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

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
