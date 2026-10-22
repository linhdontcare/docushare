import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/main.dart';
import 'package:docushare/core/constants/app_strings.dart';

void main() {
  testWidgets('DocuShare app smoke test - launches and renders dashboard', (
    WidgetTester tester,
  ) async {
    // Build DocuShareApp
    await tester.pumpWidget(const DocuShareApp());
    await tester.pumpAndSettle();

    // Verify DocuShare brand and Dashboard title exist
    expect(find.text(AppStrings.appName), findsWidgets);
    expect(find.text(AppStrings.welcomeTitle), findsOneWidget);
    expect(find.text(AppStrings.statTotalDocs), findsOneWidget);
  });
}
