import 'package:flutter_test/flutter_test.dart';
import 'package:mindmitra/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MindMitra App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MindMitraApp());
    await tester.pumpAndSettle();

    // Verify that the title appears
    expect(find.textContaining('MindMitra'), findsWidgets);
  });
}
