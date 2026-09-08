import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../domain/video_models.dart';

class YouTubeRegistrationScreen extends StatefulWidget {
  const YouTubeRegistrationScreen({super.key});
  @override
  State<YouTubeRegistrationScreen> createState() =>
      _YouTubeRegistrationScreenState();
}

class _YouTubeRegistrationScreenState extends State<YouTubeRegistrationScreen> {
  final form = GlobalKey<FormState>();
  final url = TextEditingController();
  final title = TextEditingController();
  final description = TextEditingController();
  List<VideoCategory> categories = const [];
  List<VideoCollection> collections = const [];
  String? categoryId, collectionId;
  DateTime date = DateTime.now();
  bool saving = false;
  @override
  void dispose() {
    url.dispose();
    description.dispose();
    title.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    final state = AppScope.of(context);
    try {
      await state.videoRepository!.registerYouTube(
        state.activeMembership!.church.id,
        {
          'url': url.text,
          'title': title.text,
          'recorded_at': '${date.toIso8601String().substring(0, 10)}T00:00:00Z',
          'description': description.text.isEmpty ? null : description.text,
          'category_id': categoryId,
          'collection_id': collectionId,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('YouTube URL 또는 등록 정보를 확인해주세요.')),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context);
    if (categories.isEmpty)
      Future.wait([
        s.videoRepository!.listCategories(s.activeMembership!.church.id),
        s.videoRepository!.listCollections(s.activeMembership!.church.id),
      ]).then((r) {
        if (mounted)
          setState(() {
            categories = (r[0] as List<VideoCategory>)
                .where((x) => x.isActive)
                .toList();
            collections = r[1] as List<VideoCollection>;
          });
      });
  }

  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('YouTube 영상 등록')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: url,
            decoration: const InputDecoration(labelText: 'YouTube URL'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'URL을 입력해주세요.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '설명 (선택)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: title,
            decoration: const InputDecoration(labelText: '제목'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? '제목을 입력해주세요.' : null,
          ),
          ListTile(
            title: Text(
              categoryId == null
                  ? '카테고리 선택 안 함'
                  : categories.firstWhere((x) => x.id == categoryId).name,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final id = await showModalBottomSheet<String?>(
                context: context,
                builder: (_) => ListView(
                  children: [
                    ListTile(
                      title: const Text('선택 안 함'),
                      onTap: () => Navigator.pop(context, ''),
                    ),
                    ...categories.map(
                      (x) => ListTile(
                        title: Text(x.name),
                        onTap: () => Navigator.pop(context, x.id),
                      ),
                    ),
                  ],
                ),
              );
              if (id != null)
                setState(() => categoryId = id.isEmpty ? null : id);
            },
          ),
          ListTile(
            title: Text(
              collectionId == null
                  ? '컬렉션 선택 안 함'
                  : collections.firstWhere((x) => x.id == collectionId).title,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final id = await showModalBottomSheet<String?>(
                context: context,
                builder: (_) => ListView(
                  children: [
                    ListTile(
                      title: const Text('선택 안 함'),
                      onTap: () => Navigator.pop(context, ''),
                    ),
                    ...collections
                        .where(
                          (x) =>
                              categoryId == null ||
                              x.categoryId == null ||
                              x.categoryId == categoryId,
                        )
                        .map(
                          (x) => ListTile(
                            title: Text(x.title),
                            onTap: () => Navigator.pop(context, x.id),
                          ),
                        ),
                  ],
                ),
              );
              if (id != null)
                setState(() => collectionId = id.isEmpty ? null : id);
            },
          ),
          ListTile(
            title: Text('${date.year}. ${date.month}. ${date.day}'),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => date = picked);
            },
          ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? '등록 중…' : '등록'),
          ),
        ],
      ),
    ),
  );
}
