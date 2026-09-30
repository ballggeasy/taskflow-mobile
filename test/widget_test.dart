import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskflow_mobile/main.dart';

void main() {
  testWidgets('shows tasks returned by the API', (tester) async {
    final client = MockClient((request) async => http.Response(
        '[{"id":1,"title":"write tests","done":false},{"id":2,"title":"ship it","done":true}]', 200));
    await tester.pumpWidget(TaskflowApp(api: TaskApi(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('write tests'), findsOneWidget);
    expect(find.text('ship it'), findsOneWidget);
  });

  testWidgets('shows an empty state', (tester) async {
    final client = MockClient((request) async => http.Response('[]', 200));
    await tester.pumpWidget(TaskflowApp(api: TaskApi(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('No tasks yet'), findsOneWidget);
  });
}
