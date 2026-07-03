import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/main.dart';

void main() {
  testWidgets('App launches with splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MediTrackApp());
    expect(find.text('Healfill'), findsOneWidget);
  });
}
