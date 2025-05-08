import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yapartner/main.dart';
import 'package:yapartner/models/report_response.dart';
import 'package:yapartner/screens/main_screen.dart';
import 'package:yapartner/services/token_storage.dart';
import 'mocks/yandex_api_service.mocks.dart';

void main() {
  late MockYandexApiService mockService;
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockService = MockYandexApiService();
    when(mockService.fetchAvailableFields(any)).thenAnswer((_) async => []);

    when(
      mockService.fetchMainStats(
        token: anyNamed('token'),
        from: anyNamed('from'),
        to: anyNamed('to'),
        period: anyNamed('period'),
        fields: anyNamed('fields'),
        dimensionFields: anyNamed('dimensionFields'),
        entityFields: anyNamed('entityFields'),
        limit: anyNamed('limit'),
        offset: anyNamed('offset'),
      ),
    ).thenAnswer(
      (_) async => ReportResponse(
        reportTitle: '',
        points: [],
        periods: [],
        isLastPage: true,
      ),
    );
  });
  testWidgets('TokenGate displays token input when no token is stored', (
    WidgetTester tester,
  ) async {
    // Clear token before test
    await TokenStorage.clearToken();

    await tester.pumpWidget(const MaterialApp(home: TokenGate()));

    expect(find.text('Enter OAuth Token'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('TokenGate saves token and navigates to MainPage', (
    WidgetTester tester,
  ) async {
    await TokenStorage.clearToken();

    await tester.pumpWidget(
      MaterialApp(home: TokenGate(apiService: mockService)),
    );

    await tester.enterText(find.byType(TextField), 'test-token');
    await tester.tap(find.text('Continue'));

    // Wait a few frames for token state change
    await tester.pump(); // trigger rebuild
    await tester.pump(
      const Duration(milliseconds: 500),
    ); // allow any async work

    // Ensure the MainPage is built
    expect(find.byType(MainPage), findsOneWidget);
  });

  testWidgets('Token is saved to SharedPreferences', (tester) async {
    await TokenStorage.clearToken();

    final mockService = MockYandexApiService();
    when(
      mockService.fetchAvailableFields('persisted-token'),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(
      MaterialApp(home: TokenGate(apiService: mockService)),
    );

    await tester.enterText(find.byType(TextField), 'persisted-token');
    await tester.tap(find.text('Continue'));

    await tester.pump(); // wait one frame
    await tester.pump(const Duration(seconds: 1)); // allow transition

    final token = await TokenStorage.getToken();
    expect(token, 'persisted-token');
    expect(find.byType(MainPage), findsOneWidget);
  });

  testWidgets('MainPage loads if token is already stored', (
    WidgetTester tester,
  ) async {
    final mockService = MockYandexApiService();
    when(
      mockService.fetchAvailableFields('existing-token'),
    ).thenAnswer((_) async => []);

    await TokenStorage.saveToken('existing-token');

    await tester.pumpWidget(
      MaterialApp(home: TokenGate(apiService: mockService)),
    );

    await tester.pump(); // wait one frame
    await tester.pump(const Duration(seconds: 1)); // allow transition
    expect(find.byType(MainPage), findsOneWidget);
  });

  testWidgets('Does not proceed if token field is empty', (
    WidgetTester tester,
  ) async {
    await TokenStorage.clearToken();
    await tester.pumpWidget(const MaterialApp(home: TokenGate()));

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(MainPage), findsNothing);
  });
}
