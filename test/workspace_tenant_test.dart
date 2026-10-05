import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/auth.dart';

void main() {
  test('a registered workspace is used at sign-in, not acmecorp', () async {
    final b = DemoAuthBackend(latency: Duration.zero);
    await b.register(
      name: 'Fin',
      email: 'fin@x.com',
      password: 'password123',
      organization: 'Finance Co',
      workspace: 'finance',
    );
    expect(await b.workspaceExists('finance'), isTrue);
    expect(await b.workspaceExists('acmecorp'), isTrue);
    expect(await b.findWorkspace('fin@x.com'), 'finance');
    expect((await b.signIn('fin@x.com', 'password123')).tenant!.slug, 'finance');
  });
}
