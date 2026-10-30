import 'dart:async';
import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Position;
import 'package:gomate/features/map/models/map_place.dart';
import 'package:gomate/features/map/widgets/place_bottom_sheet.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:gomate/features/search/models/search_models.dart';
import 'package:gomate/features/search/widgets/search_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/network/api_exception.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/features/place/data/place_review_repository.dart';
import 'package:gomate/features/place/data/place_api.dart';
import 'package:gomate/features/map/screens/place_detail_screen.dart';
import 'package:gomate/features/place/widgets/place_rating_builder.dart';
import 'package:gomate/features/messages/widgets/message_widgets.dart';
import 'package:gomate/core/theme/app_colors.dart';
import 'profile_posts_test.dart' as fixtures;

const place = MapPlaceUi(
  id: '9001',
  name: 'Place thật',
  subtitle: '',
  address: 'Đà Lạt',
  distanceText: '',
  openInfo: '',
  priceInfo: '',
  rating: 0,
  reviewCount: 0,
  likeCount: 0,
  tags: [],
);

class _Reviews extends PlaceReviewRepository {
  _Reviews(AuthService auth) : super(auth: auth);
  PlaceReviewState state = const PlaceReviewState(PlaceRating(0, 0), null);
  Completer<void>? gate;
  bool fail = false;
  int writes = 0;
  @override
  Future<PlaceReviewState> mine(String id) async => state;
  @override
  Future<PlaceReviewPage> page(
    String id, {
    int? before,
    String sort = 'newest',
  }) async => PlaceReviewPage(state.stats, const [], null);
  @override
  Future<PlaceReviewState> save(
    String p,
    int stars,
    String content, {
    int? reviewId,
  }) async {
    writes++;
    if (gate != null) await gate!.future;
    if (fail)
      throw const ApiException(503, 'NETWORK_ERROR', 'Mất mạng thử lại');
    state = PlaceReviewState(
      PlaceRating(stars.toDouble(), 1),
      PlaceReview(id: reviewId ?? 1, rating: stars, content: content),
    );
    PlaceRatingChanges.acknowledge(p, state.stats);
    return state;
  }

  @override
  Future<PlaceReviewState> delete(String p, int id) async {
    state = const PlaceReviewState(PlaceRating(0, 0), null);
    PlaceRatingChanges.acknowledge(p, state.stats);
    return state;
  }
}

PlaceApi api() => PlaceApi(
  baseUrls: ['http://test/api/v1'],
  client: MockClient(
    (r) async => http.Response(
      jsonEncode({
        'id': 9001,
        'name': 'Place thật',
        'category': {'id': 1, 'code': 'nature', 'name': 'Thiên nhiên'},
        'province': 'Đà Lạt',
        'latitude': 11.9,
        'longitude': 108.4,
        'avgRating': 0,
        'reviewCount': 0,
        'saveCount': 0,
        'sourceType': 'ADMIN',
        'status': 'ACTIVE',
        'media': [],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
);

void main() {
  for (final average in <double?>[null, 0, 5]) {
    test('zero count is unrated even with legacy average $average', () {
      final r = PlaceRating(average, 0);
      expect(r.display, 0);
      expect(r.count, 0);
      expect(r.label, 'Chưa có đánh giá');
      expect(r.compactLabel, 'Chưa có đánh giá');
      expect(r.hasValidRating, isFalse);
    });
  }
  test('real counts preserve averages and invalid averages are explicit', () {
    expect(const PlaceRating(5, 1).label, '5.0 (1)');
    expect(const PlaceRating(4, 2).label, '4.0 (2)');
    expect(const PlaceRating(3.5, 2).label, '3.5 (2)');
    for (final average in <double?>[null, 0, double.nan, 6]) {
      final r = PlaceRating(average, 2);
      expect(r.label, contains('chưa khả dụng'));
      expect(r.label, isNot(contains('Chưa có đánh giá')));
      expect(r.hasValidRating, isFalse);
    }
  });
  test(
    'review DTO tolerates an unrated null average without inventing a vote',
    () {
      final r = PlaceReviewState.fromJson({
        'avgRating': null,
        'reviewCount': 0,
        'myReview': null,
      });
      expect(r.stats.label, 'Chưa có đánh giá');
      expect(r.stats.count, 0);
    },
  );
  testWidgets(
    'Search badge uses count, remains bounded and updates after ACK',
    (t) async {
      Widget card() => const MaterialApp(
        home: Scaffold(
          body: SearchPlaceCard(
            item: SearchPlaceItem(
              id: 99001,
              name: 'Place Search',
              location: 'Đà Lạt',
              rating: 5,
              imageUrl: null,
            ),
            width: 140,
            height: 210,
          ),
        ),
      );
      await t.pumpWidget(card());
      expect(find.text('Chưa có đánh giá'), findsOneWidget);
      expect(find.text('5,0'), findsNothing);
      expect(t.takeException(), isNull);
      PlaceRatingChanges.acknowledge('99001', const PlaceRating(4, 2));
      await t.pump();
      expect(find.text('4,0 (2)'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(card());
      expect(find.text('4,0 (2)'), findsOneWidget);
      PlaceRatingChanges.acknowledge('99001', const PlaceRating(0, 0));
      await t.pump();
      expect(find.text('Chưa có đánh giá'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Map selected-place card updates only rating after review ACK', (
    t,
  ) async {
    final p = GoMateMapPlace(
      placeId: '99002',
      name: 'Place Map',
      categoryLabel: 'Thiên nhiên',
      address: 'Đà Lạt',
      rating: 5,
      reviewCount: 0,
      isSaved: false,
      category: GoMatePlaceCategory.nature,
      position: Position(108, 11),
    );
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoMatePlaceBottomSheet(
            place: p,
            onClose: () {},
            onToggleSaved: () {},
            onDirections: () {},
            onOpenDetail: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Chưa có đánh giá'), findsOneWidget);
    expect(find.textContaining('5.0'), findsNothing);
    PlaceRatingChanges.acknowledge('99002', const PlaceRating(5, 1));
    await t.pump();
    expect(find.textContaining('5.0 (1)'), findsOneWidget);
    PlaceRatingChanges.acknowledge('99002', const PlaceRating(0, 0));
    await t.pump();
    expect(find.textContaining('Chưa có đánh giá'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'detail and all-reviews use empty label and unselected input stars',
    (t) async {
      t.view.physicalSize = const Size(411, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final auth = await fixtures.auth();
      final repo = _Reviews(auth);
      final client = api();
      await t.pumpWidget(
        MaterialApp(
          home: PlaceDetailScreen(
            place: place,
            reviewRepository: repo,
            placeApi: client,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('5.0 ·'), findsNothing);
      expect(find.textContaining('0.0'), findsNothing);
      final star = find.byKey(const ValueKey('place-review-open-5'));
      await t.scrollUntilVisible(
        star,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        t
            .widget<Icon>(
              find.descendant(of: star, matching: find.byType(Icon)),
            )
            .icon,
        LucideIcons.star,
      );
      await t.tap(find.text('(0) Xem tất cả'));
      await t.pumpAndSettle();
      expect(find.text('Chưa có đánh giá'), findsWidgets);
      expect(find.text('5,0'), findsNothing);
      expect(find.text('0,0'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      client.close();
      auth.dispose();
    },
  );
  test(
    'an older Place read cannot overwrite a newer rating mutation ACK',
    () async {
      final response = Completer<http.Response>();
      final client = PlaceApi(
        baseUrls: ['http://test/api/v1'],
        client: MockClient((_) => response.future),
      );
      final pending = client.listPlaces();
      PlaceRatingChanges.acknowledge('777', const PlaceRating(4, 2));
      response.complete(
        http.Response(
          jsonEncode([
            {
              'placeId': 777,
              'name': 'Place',
              'category': 'nature',
              'categoryName': 'Nature',
              'latitude': 11,
              'longitude': 108,
              'province': 'Dalat',
              'avgRating': 0,
              'reviewCount': 0,
            },
          ]),
          200,
        ),
      );
      await pending;
      expect(PlaceRatingChanges.forPlace('777').value?.average, 4);
      expect(PlaceRatingChanges.forPlace('777').value?.count, 2);
      client.close();
    },
  );
  testWidgets(
    'rating ACK rebuilds only the badge and preserves sibling media',
    (t) async {
      int mediaBuilds = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Builder(
                  builder: (_) {
                    mediaBuilds++;
                    return const Text('Media');
                  },
                ),
                PlaceRatingBuilder(
                  placeId: 'badge',
                  average: 0,
                  count: 0,
                  builder: (r) => Text(r.label),
                ),
              ],
            ),
          ),
        ),
      );
      PlaceRatingChanges.acknowledge('badge', const PlaceRating(4, 2));
      await t.pump();
      expect(find.text('4.0 (2)'), findsOneWidget);
      expect(mediaBuilds, 1);
    },
  );
  testWidgets(
    'real composer waits ACK, keeps network error, edits, rehydrates and deletes',
    (t) async {
      t.view.physicalSize = const Size(411, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final auth = await fixtures.auth();
      final repo = _Reviews(auth);
      final client = api();
      Widget screen() => MaterialApp(
        home: PlaceDetailScreen(
          place: place,
          reviewRepository: repo,
          placeApi: client,
        ),
      );
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      expect(find.text('Caption, đánh giá'), findsNothing);
      // Existing five selectable stars above the review cards.
      final star = find.byKey(const ValueKey('place-review-open-5'));
      await t.scrollUntilVisible(
        star,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(star);
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('place-review-content')),
        findsOneWidget,
      );
      await t.enterText(
        find.byKey(const ValueKey('place-review-content')),
        'Review thật',
      );
      repo.gate = Completer<void>();
      await t.tap(find.text('Đăng'));
      await t.pump();
      expect(find.text('Đang lưu…'), findsOneWidget);
      expect(repo.state.mine, isNull);
      repo.fail = true;
      repo.gate!.complete();
      await t.pumpAndSettle();
      expect(find.text('Mất mạng thử lại'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('place-review-content')),
        findsOneWidget,
      );
      repo.fail = false;
      repo.gate = null;
      await t.tap(find.text('Đăng'));
      await t.pumpAndSettle();
      expect(repo.state.mine?.rating, 5);
      expect(find.text('Review thật'), findsOneWidget);
      await Scrollable.ensureVisible(
        t.element(find.text('Chỉnh sửa')),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Chỉnh sửa'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('place-review-star-3')));
      await t.tap(find.text('Chỉnh sửa').last);
      await t.pumpAndSettle();
      expect(repo.state.mine?.rating, 3);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Chỉnh sửa'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Review thật'), findsOneWidget);
      await Scrollable.ensureVisible(
        t.element(find.byTooltip('Xóa đánh giá')),
        alignment: 0.5,
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Xóa đánh giá'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(MessageConfirmContent), findsOneWidget);
      expect(
        t.widget<Text>(find.text('Xóa đánh giá?')).style?.color,
        Colors.black,
      );
      final close = t.widget<TextButton>(
        find.widgetWithText(TextButton, 'Đóng'),
      );
      expect(close.style?.foregroundColor?.resolve({}), AppColors.grayText);
      await t.tap(find.text('Đóng'));
      await t.pumpAndSettle();
      expect(repo.state.mine?.rating, 3);
      await t.tap(find.byTooltip('Xóa đánh giá'));
      await t.pumpAndSettle();
      await t.tap(find.text('Xóa'));
      await t.pumpAndSettle();
      expect(repo.state.mine, isNull);
      expect(repo.state.stats.count, 0);
      await repo.save(place.id, 3, 'Own private state');
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      expect(find.text('Own private state'), findsOneWidget);
      await auth.clearLocal();
      await t.pumpAndSettle();
      expect(find.text('Own private state'), findsNothing);
      await t.pumpWidget(const SizedBox());
      client.close();
      auth.dispose();
    },
  );
}
