import 'package:church_app/features/home/presentation/home_screen.dart';
import 'package:church_app/features/notices/domain/notice_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('최근 공지는 Backend 순서대로 최대 세 개와 고정 표시를 렌더링한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentNoticesSection(
            notices: [
              _notice('1', '고정 공지', true),
              _notice('2', '두 번째', false),
              _notice('3', '세 번째', false),
              _notice('4', '네 번째', false),
            ],
          ),
        ),
      ),
    );
    expect(find.text('최근 공지사항'), findsOneWidget);
    expect(find.text('고정 공지'), findsOneWidget);
    expect(find.text('네 번째'), findsNothing);
    expect(find.text('고정 · 2026.09.01'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
    expect(find.text('홈에 표시되면 안 되는 본문'), findsNothing);
  });
  testWidgets('최근 공지는 빈 목록을 compact empty state로 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RecentNoticesSection(notices: [])),
      ),
    );
    expect(find.text('등록된 공지사항이 없습니다.'), findsOneWidget);
  });
}

Notice _notice(String id, String title, bool pinned) {
  final at = DateTime(2026, 9, int.parse(id));
  return Notice(
    id: id,
    churchId: 'church',
    title: title,
    content: '홈에 표시되면 안 되는 본문',
    isPinned: pinned,
    publishedAt: at,
    createdAt: at,
    updatedAt: at,
  );
}
