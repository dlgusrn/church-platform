import 'package:church_app/app/app_scope.dart';
import 'package:church_app/app/app_state.dart';
import 'package:church_app/core/auth/mock_auth_repository.dart';
import 'package:church_app/core/mock/mock_app_data_store.dart';
import 'package:church_app/core/permission/mock_role_repository.dart';
import 'package:church_app/features/church/data/mock_church_repository.dart';
import 'package:church_app/features/church/data/mock_membership_repository.dart';
import 'package:church_app/features/home/data/mock_home_repository.dart';
import 'package:church_app/features/live/data/mock_live_access_service.dart';
import 'package:church_app/features/notices/data/mock_notice_repository.dart';
import 'package:church_app/features/video/data/mock_video_repository.dart';
import 'package:church_app/features/video/domain/video_models.dart';
import 'package:church_app/features/video/presentation/video_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReviewRepository extends MockVideoRepository {
  List<VideoItem> videos = [
    _video('1', '검수할 긴 제목의 NAS 영상입니다'),
    _video('2', '두 번째 NAS 영상'),
    _video('3', '공개된 영상', published: true),
  ];
  int pageLength = 100;
  final published = <String>[];
  Map<String, dynamic>? lastUpdate;

  static VideoItem _video(String id, String title, {bool published = false}) =>
      VideoItem(
        id: id,
        churchId: 'church-a',
        title: title,
        sourceType: VideoSourceType.synology,
        sourceRef: '',
        recordedAt: DateTime(2026, 1, 4),
        isPublished: published,
      );

  @override
  Future<Map<String, dynamic>> reviewVideos(
    String churchId, {
    String status = 'unpublished',
    int offset = 0,
    int limit = 100,
  }) async {
    final filtered = videos
        .where(
          (video) => switch (status) {
            'unpublished' => !video.isPublished,
            'published' => video.isPublished,
            _ => true,
          },
        )
        .toList();
    return {
      'items': [
        for (final video in filtered.skip(offset).take(pageLength)) _map(video),
      ],
      'total': filtered.length,
      'published_count': videos.where((video) => video.isPublished).length,
      'unpublished_count': videos.where((video) => !video.isPublished).length,
      'offset': offset,
      'limit': limit,
    };
  }

  @override
  Future<Map<String, dynamic>> bulkPublish(
    String churchId,
    List<String> videoIds,
  ) async {
    published.addAll(videoIds);
    for (var index = 0; index < videos.length; index++) {
      if (videoIds.contains(videos[index].id)) {
        videos[index] = _video(
          videos[index].id,
          videos[index].title,
          published: true,
        );
      }
    }
    return {
      'requested_count': videoIds.length,
      'published_count': videoIds.length,
      'already_published_count': 0,
      'failed_count': 0,
      'items': [
        for (final id in videoIds)
          {
            'status': 'published',
            'video_id': int.parse(id),
            'error_code': null,
          },
      ],
    };
  }

  @override
  Future<VideoItem> updateVideo(
    String churchId,
    String videoId,
    Map<String, dynamic> request,
  ) async {
    lastUpdate = request;
    final current = videos.firstWhere((video) => video.id == videoId);
    final updated = _video(
      videoId,
      request['title'] as String? ?? current.title,
      published: request['is_published'] as bool? ?? current.isPublished,
    );
    videos[videos.indexWhere((video) => video.id == videoId)] = updated;
    return updated;
  }

  static Map<String, dynamic> _map(VideoItem video) => {
    'id': int.parse(video.id),
    'church_id': video.churchId,
    'title': video.title,
    'description': null,
    'source_type': 'synology',
    'recorded_at': video.recordedAt.toUtc().toIso8601String(),
    'duration_seconds': null,
    'thumbnail_ref': null,
    'is_published': video.isPublished,
    'category_id': null,
    'collection_id': null,
  };
}

({AppState state, _ReviewRepository repo}) _fixture() {
  final store = MockAppDataStore();
  final repo = _ReviewRepository();
  final user = store.userById('user-b')!;
  return (
    repo: repo,
    state:
        AppState(
            authRepository: MockAuthRepository(store),
            churchRepository: MockChurchRepository(store),
            membershipRepository: MockMembershipRepository(store),
            roleRepository: MockRoleRepository(store),
            homeRepository: MockHomeRepository(),
            liveAccessService: MockLiveAccessService(),
            noticeRepository: MockNoticeRepository(),
            videoRepository: repo,
          )
          ..currentUser = user
          ..activeMembership = user.approvedMemberships.single
          ..status = AppSessionStatus.authenticated,
  );
}

void main() {
  testWidgets(
    'unpublished is default, selected loaded rows publish after confirmation',
    (tester) async {
      final fixture = _fixture();
      await tester.pumpWidget(
        AppScope(
          state: fixture.state,
          child: const MaterialApp(home: VideoReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('비공개 2개'), findsOneWidget);
      expect(find.text('검수할 긴 제목의 NAS 영상입니다'), findsOneWidget);
      await tester.tap(find.text('현재 목록 전체 선택'));
      await tester.pump();
      expect(find.text('선택한 2개 공개하기'), findsOneWidget);
      await tester.tap(find.text('선택한 2개 공개하기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('성도에게 영상이 표시됩니다.'), findsOneWidget);
      await tester.tap(find.text('공개하기').last);
      await tester.pumpAndSettle();
      expect(fixture.repo.published, ['1', '2']);
      expect(find.textContaining('영상 공개 완료'), findsOneWidget);
      expect(find.text('검수할 비공개 영상이 없습니다.'), findsOneWidget);
    },
  );

  testWidgets(
    'review selection is guarded at 200',
    (tester) async {
      final fixture = _fixture();
      fixture.repo.pageLength = 201;
      fixture.repo.videos = List.generate(
        201,
        (index) => _ReviewRepository._video('${index + 1}', '영상 $index'),
      );
      await tester.pumpWidget(
        AppScope(
          state: fixture.state,
          child: const MaterialApp(home: VideoReviewScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('현재 목록 전체 선택'));
      await tester.pump();
      await tester.tap(find.text('선택한 201개 공개하기'));
      await tester.pump();
      expect(find.text('한 번에 최대 200개까지 공개할 수 있습니다.'), findsOneWidget);
      expect(fixture.repo.published, isEmpty);
    },
  );

  testWidgets('row edit saves title and nullable category and collection', (
    tester,
  ) async {
    final fixture = _fixture();
    await tester.pumpWidget(
      AppScope(
        state: fixture.state,
        child: const MaterialApp(home: VideoReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('검수할 긴 제목의 NAS 영상입니다'));
    await tester.pumpAndSettle();
    expect(find.text('영상 정보 수정'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '수정한 제목');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(fixture.repo.lastUpdate!['title'], '수정한 제목');
    expect(fixture.repo.lastUpdate!['category_id'], isNull);
    expect(fixture.repo.lastUpdate!['collection_id'], isNull);
    expect(find.text('수정한 제목'), findsOneWidget);
  });
}
