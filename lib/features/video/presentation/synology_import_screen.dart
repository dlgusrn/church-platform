import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_tokens.dart';

class SynologyImportScreen extends StatefulWidget {
  const SynologyImportScreen({super.key});
  @override
  State<SynologyImportScreen> createState() => _SynologyImportScreenState();
}

class _SynologyImportScreenState extends State<SynologyImportScreen> {
  bool loading = false, importing = false;
  String? error, token;
  Map<String, dynamic>? connection, summary;
  List<Map<String, dynamic>> candidates = [];
  String filter = '전체';
  String get churchId => AppScope.of(context).activeMembership!.church.id;
  Future<void> test() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      connection = await AppScope.of(context).videoRepository!
          .testSynology(churchId);
    } catch (_) {
      error = '연결을 확인할 수 없습니다. 다시 시도해주세요.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> scan() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await AppScope.of(context).videoRepository!
          .previewSynology(churchId);
      token = r['snapshot_token'] as String?;
      summary = (r['summary'] as Map?)?.cast<String, dynamic>();
      candidates = ((r['candidates'] as List?) ?? [])
          .map((x) => (x as Map).cast<String, dynamic>())
          .toList();
    } catch (_) {
      error = '영상 검색에 실패했습니다. 연결 상태를 확인해주세요.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> import() async {
    final refs = candidates
        .where((x) => x['duplicate'] != true)
        .map((x) => x['source_ref'] as String)
        .toList();
    if (token == null || refs.isEmpty) return;
    setState(() => importing = true);
    try {
      await AppScope.of(context).videoRepository!
          .importSynology(churchId, token!, refs);
      await scan();
    } catch (_) {
      if (mounted) setState(() => error = '가져오기에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = candidates
        .where(
          (x) =>
              filter == '전체' ||
              (filter == '신규' && !(x['duplicate'] as bool? ?? false)) ||
              (filter == '이미 등록됨' && (x['duplicate'] as bool? ?? false)) ||
              (filter == '확인 필요' &&
                  ((x['warnings'] as List?)?.isNotEmpty ?? false)),
        )
        .toList();
    final fresh = candidates.where((x) => x['duplicate'] != true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('NAS 영상 가져오기')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Synology NAS',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                connection == null
                    ? '연결 상태를 확인해주세요.'
                    : connection!['root_accessible'] == true
                    ? '연결됨 · 영상 폴더 접근 가능'
                    : '연결 또는 영상 폴더를 확인해주세요.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: loading ? null : test,
                child: const Text('연결 확인'),
              ),
              FilledButton(
                onPressed: loading ? null : scan,
                child: Text(loading ? '처리 중…' : '영상 검색'),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          if (summary != null) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _count('총 영상', summary!['total']),
                _count('신규', summary!['new']),
                _count('이미 등록됨', summary!['duplicate']),
                _count('확인 필요', summary!['warning']),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['전체', '신규', '확인 필요', '이미 등록됨']
                    .map(
                      (x) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(x),
                          selected: filter == x,
                          onSelected: (_) => setState(() => filter = x),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            ...shown.map(_row),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: importing || fresh == 0 ? null : import,
              child: Text(importing ? '가져오는 중…' : '$fresh개 영상 가져오기'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _count(String label, dynamic value) =>
      Chip(label: Text('$label ${value ?? 0}'));
  Widget _row(Map<String, dynamic> x) =>
      _SynologyCandidateRow(candidate: x, leading: null);
}

/// [leading] is intentionally reserved for the Stage 9-4B selection control.
class _SynologyCandidateRow extends StatelessWidget {
  const _SynologyCandidateRow({required this.candidate, this.leading});

  final Map<String, dynamic> candidate;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final metadata =
        [candidate['category_suggestion'], candidate['collection_suggestion']]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .join(' · ');
    final duplicate = candidate['duplicate'] as bool? ?? false;
    final needsReview = (candidate['warnings'] as List?)?.isNotEmpty ?? false;
    final status = duplicate
        ? '이미 등록됨'
        : needsReview
        ? '확인 필요'
        : '신규';
    final statusColors = duplicate
        ? (AppColors.surfaceMuted, AppColors.textSecondary)
        : needsReview
        ? (AppColors.warningSoft, AppColors.warning)
        : (AppColors.successSoft, AppColors.success);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${candidate['inferred_title']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _StatusBadge(
                          label: status,
                          background: statusColors.$1,
                          foreground: statusColors.$2,
                        ),
                      ],
                    ),
                    if (metadata.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        metadata,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.folder_outlined,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            '${candidate['relative_path']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      ],
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
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });
  final String label;
  final Color background;
  final Color foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: foreground),
    ),
  );
}
