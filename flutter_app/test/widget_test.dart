import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app/app.dart';

void main() {
  testWidgets('shows setup guidance when public Supabase config is absent', (tester) async {
    await tester.pumpWidget(const NexusApp());
    expect(find.text('Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY para iniciar o NEXUS.'), findsOneWidget);
  });
}
