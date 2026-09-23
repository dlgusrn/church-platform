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
import 'package:church_app/features/video/data/video_repository.dart';
import 'package:church_app/features/video/presentation/synology_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SynologyVideoRepository extends MockVideoRepository {
  final imported = <String>[];
  final calls =
      <({String? token, int offset, String status, String? folder})>[];
  bool expireNext = false;
  bool permissionError = false;
  bool partialFailure = false;
  bool candidateOutOfSnapshot = false;
  int pageLength = 2;
  List<Map<String, dynamic>> items = [
    _item('ready-a', '가져올 영상', path: 'folder-a/ready-a.mp4'),
    _item(
      'registered-b',
      '등록된 영상',
      alreadyImported: true,
      path: 'folder-a/registered-b.mp4',
    ),
    _item(
      'review-c',
      '검토 영상',
      needsReview: true,
      reasons: ['missing_recorded_at'],
      path: '2026/09/review-c.mp4',
    ),
    _item(
      'unknown-d',
      '알 수 없는 사유',
      needsReview: true,
      reasons: ['future_reason'],
      path: '2026/09/unknown-d.mp4',
    ),
  ];

  static Map<String, dynamic> _item(
    String ref,
    String title, {
    bool alreadyImported = false,
    bool needsReview = false,
    List<String> reasons = const [],
    required String path,
  }) => {
    'source_ref': ref,
    'relative_path': path,
    'inferred_title': title,
    'inferred_recorded_at': needsReview ? null : '2026-01-04T00:00:00Z',
    'file_size': 2048,
    'extension': 'mp4',
    'already_imported': alreadyImported,
    'duplicate': alreadyImported,
    'needs_review': needsReview,
    'review_reasons': reasons,
    'warnings': reasons,
  };

  @override
  Future<Map<String, dynamic>> previewSynology(
    String churchId, {
    String? snapshotToken,
    int offset = 0,
    int limit = 100,
    String status = 'all',
    String? folder,
  }) async {
    if (permissionError) throw const SynologyPermissionException();
    if (expireNext && snapshotToken != null)
      throw const SynologySnapshotExpiredException();
    calls.add((
      token: snapshotToken,
      offset: offset,
      status: status,
      folder: folder,
    ));
    final filtered = items.where((item) {
      final matchesFolder =
          folder == null ||
          (item['relative_path'] as String).startsWith('$folder/');
      final imported = item['already_imported'] == true;
      final review = item['needs_review'] == true;
      final matchesStatus = switch (status) {
        'ready' => !imported && !review,
        'needs_review' => review,
        'already_imported' => imported,
        _ => true,
      };
      return matchesFolder && matchesStatus;
    }).toList();
    return {
      'snapshot_token': snapshotToken ?? 'snapshot-1',
      'summary': {
        'total': items.length,
        'filtered_total': filtered.length,
        'new': items.where((item) => item['already_imported'] != true).length,
        'already_imported': items
            .where((item) => item['already_imported'] == true)
            .length,
        'needs_review': items
            .where((item) => item['needs_review'] == true)
            .length,
        'ready': items
            .where(
              (item) =>
                  item['already_imported'] != true &&
                  item['needs_review'] != true,
            )
            .length,
      },
      'candidates': filtered.skip(offset).take(pageLength).toList(),
      'folder_facets': ['2026', '2026/09', 'folder-a'],
      'selectable_source_refs': filtered
          .where((item) => item['already_imported'] != true)
          .map((item) => item['source_ref'])
          .toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> importSynology(
    String churchId,
    String token,
    List<String> refs,
  ) async {
    if (permissionError) throw const SynologyPermissionException();
    imported.addAll(refs);
    final completedRefs = candidateOutOfSnapshot
        ? <String>[]
        : partialFailure && refs.length > 1
        ? refs.take(1)
        : refs;
    for (final item in items.where(
      (item) => completedRefs.contains(item['source_ref']),
    )) {
      item['already_imported'] = true;
      item['duplicate'] = true;
    }
    return {
      'requested_count': refs.length,
      'imported_count': completedRefs.length,
      'already_imported_count': 0,
      'failed_count': refs.length - completedRefs.length,
      'needs_review_count': 0,
      'items': [
        for (var index = 0; index < refs.length; index++)
          {
            'status': index < completedRefs.length ? 'imported' : 'failed',
            'video_id': index < completedRefs.length ? 1 : null,
            'error_code': index < completedRefs.length
                ? null
                : candidateOutOfSnapshot
                ? 'candidate_not_in_snapshot'
                : 'import_failed',
          },
      ],
      'created': refs.length,
      'skipped': 0,
      'failed': 0,
    };
  }
}

({AppState state, _SynologyVideoRepository video}) _fixture() {
  final store = MockAppDataStore();
  final video = _SynologyVideoRepository();
  final user = store.userById('user-b')!;
  return (
    video: video,
    state:
        AppState(
            authRepository: MockAuthRepository(store),
            churchRepository: MockChurchRepository(store),
            membershipRepository: MockMembershipRepository(store),
            roleRepository: MockRoleRepository(store),
            homeRepository: MockHomeRepository(),
            liveAccessService: MockLiveAccessService(),
            noticeRepository: MockNoticeRepository(),
            videoRepository: video,
          )
          ..currentUser = user
          ..activeMembership = user.approvedMemberships.single
          ..status = AppSessionStatus.authenticated,
  );
}

Future<void> _open(
  WidgetTester tester,
  ({AppState state, _SynologyVideoRepository video}) fixture,
) async {
  await tester.pumpWidget(
    AppScope(
      state: fixture.state,
      child: const MaterialApp(home: SynologyImportScreen()),
    ),
  );
  await tester.tap(find.text('영상 검색'));
  await tester.pumpAndSettle();
}

Future<void> _chooseStatus(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'snapshot summary, status/folder filters, selection and import refresh use the existing snapshot',
    (tester) async {
      final fixture = _fixture();
      await _open(tester, fixture);

      expect(find.text('총 4개'), findsOneWidget);
      expect(find.text('가져오기 가능 1개'), findsOneWidget);
      expect(find.text('검토 필요 2개'), findsOneWidget);
      await tester.tap(find.text('현재 목록 전체 선택'));
      await tester.pump();
      expect(find.text('선택 1개'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('더 보기'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('더 보기'));
      await tester.pumpAndSettle();
      expect(find.text('검토 영상'), findsOneWidget);
      expect(find.text('확인 필요'), findsOneWidget); // unknown reason fallback
      expect(find.text('선택 1개'), findsOneWidget);

      await _chooseStatus(tester, '가져오기 가능');
      await _chooseStatus(tester, '검토 필요');
      await _chooseStatus(tester, '이미 등록됨');
      expect(
        fixture.video.calls.map((call) => call.status),
        containsAll(['ready', 'needs_review', 'already_imported']),
      );
      expect(find.text('등록된 영상'), findsOneWidget);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2026').last);
      await tester.pumpAndSettle();
      expect(fixture.video.calls.last.folder, '2026');

      await _chooseStatus(tester, '전체');
      await tester.tap(find.text('선택한 1개 가져오기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('가져온 영상은 바로 공개되지 않으며'), findsOneWidget);
      await tester.tap(find.text('가져오기').last);
      await tester.pumpAndSettle();
      expect(fixture.video.imported, ['ready-a']);
      expect(find.textContaining('영상 가져오기 완료'), findsOneWidget);
      expect(fixture.video.calls.last.token, 'snapshot-1');
    },
  );

  testWidgets('snapshot and permission errors have safe recovery messages', (
    tester,
  ) async {
    final fixture = _fixture();
    await _open(tester, fixture);
    fixture.video.expireNext = true;
    await _chooseStatus(tester, '가져오기 가능');
    expect(find.text('NAS 목록을 다시 불러와 주세요.'), findsOneWidget);
    expect(find.text('다시 검색'), findsOneWidget);

    fixture.video.expireNext = false;
    fixture.video.permissionError = true;
    await tester.tap(find.text('다시 검색'));
    await tester.pumpAndSettle();
    expect(find.text('영상 관리 권한이 없습니다.'), findsOneWidget);
  });

  testWidgets(
    'partial import failure is shown without exposing backend details',
    (tester) async {
      final fixture = _fixture();
      fixture.video.items = [
        _SynologyVideoRepository._item('ready-a', '첫 영상', path: 'bulk/a.mp4'),
        _SynologyVideoRepository._item('ready-b', '둘째 영상', path: 'bulk/b.mp4'),
      ];
      fixture.video.pageLength = 2;
      fixture.video.partialFailure = true;
      await _open(tester, fixture);
      await tester.tap(find.text('현재 목록 전체 선택'));
      await tester.pump();
      await tester.tap(find.text('선택한 2개 가져오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('가져오기').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('일부 영상을 가져오지 못했습니다.'), findsOneWidget);
      expect(find.text('import_failed'), findsNothing);
    },
  );

  testWidgets(
    'stale candidate result asks the administrator to reload safely',
    (tester) async {
      final fixture = _fixture();
      fixture.video.items = [
        _SynologyVideoRepository._item('ready-a', '첫 영상', path: 'bulk/a.mp4'),
      ];
      fixture.video.candidateOutOfSnapshot = true;
      await _open(tester, fixture);
      await tester.tap(find.text('현재 목록 전체 선택'));
      await tester.pump();
      await tester.tap(find.text('선택한 1개 가져오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('가져오기').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('선택한 영상 정보를 다시 불러와 주세요.'), findsOneWidget);
      expect(find.text('candidate_not_in_snapshot'), findsNothing);
    },
  );

  testWidgets(
    '200 can be confirmed and 201 is blocked before an import request',
    (tester) async {
      final fixture = _fixture();
      fixture.video.pageLength = 201;
      fixture.video.items = List.generate(
        201,
        (index) => _SynologyVideoRepository._item(
          'ready-$index',
          '영상 $index',
          path: 'bulk/$index.mp4',
        ),
      );
      await _open(tester, fixture);
      await tester.tap(find.text('현재 목록 전체 선택'));
      await tester.pump();
      expect(find.text('선택 201개'), findsOneWidget);
      await tester.tap(find.text('선택한 201개 가져오기'));
      await tester.pump();
      expect(find.text('한 번에 최대 200개까지 가져올 수 있습니다.'), findsOneWidget);
      expect(fixture.video.imported, isEmpty);

      fixture.video.items = fixture.video.items.take(200).toList();
      await tester.tap(find.text('영상 검색'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('현재 목록 전체 선택'));
      await tester.pump();
      expect(find.text('선택 200개'), findsOneWidget);
      await tester.tap(find.text('선택한 200개 가져오기'));
      await tester.pumpAndSettle();
      expect(find.text('영상 가져오기'), findsOneWidget);
    },
  );
}
