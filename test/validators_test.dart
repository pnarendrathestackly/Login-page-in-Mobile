import 'package:flutter_test/flutter_test.dart';
import 'package:stackly_auth/widgets.dart';

void main() {
  test('email validator', () {
    expect(emailValidator(''), isNotNull);
    expect(emailValidator('nope'), isNotNull);
    expect(emailValidator('a@b'), isNotNull);
    expect(emailValidator('a b@c.com'), isNotNull);
    expect(emailValidator(' me@stackly.com '), isNull);
  });

  test('password validator', () {
    expect(passwordValidator(''), isNotNull);
    expect(passwordValidator('short'), isNotNull);
    expect(passwordValidator('longenough'), isNull);
  });
}
