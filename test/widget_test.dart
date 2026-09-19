import 'package:flutter_test/flutter_test.dart';
import 'package:gestione_familiare/main.dart';

void main() {
  testWidgets('Gestione Familiare starts', (tester) async {
    await tester.pumpWidget(const GestioneFamiliareApp());
    expect(find.text('Gestione Familiare'), findsOneWidget);
  });
}
