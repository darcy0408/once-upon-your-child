import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/big_feelings_flow_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BigFeelingsFlowScreen()),
    );
    await pumpFor(tester, const Duration(seconds: 1));

    expect(find.byType(BigFeelingsFlowScreen), findsOneWidget);
  });
}
