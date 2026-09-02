import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_theme.dart';
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

  Future<void> _edit([WorshipSchedule? schedule]) async {
    final draft = await showDialog<WorshipScheduleDraft>(
      context: context,
      builder: (_) => _ScheduleDialog(schedule: schedule),
    );
    if (draft == null || !mounted) return;
    try {
      await AppScope.of(context)
          .saveWorshipSchedule(draft, scheduleId: schedule?.id);
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
    appBar: AppBar(title: const Text('예배 일정 관리')),
    floatingActionButton: FloatingActionButton(
      onPressed: _edit,
      child: const Icon(Icons.add),
    ),
    body: FutureBuilder<List<WorshipSchedule>>(
      future: _items,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError)
            return Center(child: Text('${snapshot.error}'));
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) return const Center(child: Text('등록된 예배 일정이 없습니다.'));
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                onTap: () => _edit(item),
                title: Text(item.name),
                subtitle: Text(
                  '${item.dayLabel} · ${item.displayTime} · 순서 ${item.displayOrder}',
                ),
                trailing: Text(
                  item.isActive ? '사용' : '미사용',
                  style: TextStyle(
                    color: item.isActive ? AppTheme.primary : AppTheme.muted,
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({this.schedule});
  final WorshipSchedule? schedule;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late final TextEditingController _name;
  late final TextEditingController _order;
  late final TextEditingController _dayLabel;
  late TimeOfDay _time;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    _name = TextEditingController(text: schedule?.title ?? '');
    _dayLabel = TextEditingController(text: schedule?.dayLabel ?? '');
    _order = TextEditingController(text: '${schedule?.displayOrder ?? 0}');
    if (schedule == null) {
      _time = TimeOfDay.now();
    } else {
      final parts = schedule.time.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    _active = schedule?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _dayLabel.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.schedule == null ? '예배 일정 추가' : '예배 일정 수정'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '예배명'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dayLabel,
            decoration: const InputDecoration(labelText: '요일/안내 문구'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('시작 시간'),
            trailing: Text(_time.format(context)),
            onTap: () async {
              final selected = await showTimePicker(
                context: context,
                initialTime: _time,
              );
              if (selected != null) setState(() => _time = selected);
            },
          ),
          TextField(
            controller: _order,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '표시 순서'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('활성화'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
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
          if (_name.text.trim().isEmpty || _dayLabel.text.trim().isEmpty)
            return;
          Navigator.pop(
            context,
            WorshipScheduleDraft(
              title: _name.text.trim(),
              dayLabel: _dayLabel.text.trim(),
              time:
                  '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00',
              displayOrder: int.tryParse(_order.text) ?? 0,
              isActive: _active,
            ),
          );
        },
        child: const Text('저장'),
      ),
    ],
  );
}
