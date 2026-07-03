import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';

void main() {
  test('ruDays uses the singular form for 1, 21, 101', () {
    expect(ruDays(1), '1 день');
    expect(ruDays(21), '21 день');
    expect(ruDays(101), '101 день');
  });

  test('ruDays uses the paucal form for 2-4, 22-24', () {
    expect(ruDays(2), '2 дня');
    expect(ruDays(3), '3 дня');
    expect(ruDays(4), '4 дня');
    expect(ruDays(22), '22 дня');
    expect(ruDays(34), '34 дня');
    expect(ruDays(102), '102 дня');
  });

  test('ruDays uses the plural form for 0, 5-20, 25-30', () {
    expect(ruDays(0), '0 дней');
    expect(ruDays(5), '5 дней');
    expect(ruDays(7), '7 дней');
    expect(ruDays(10), '10 дней');
    expect(ruDays(20), '20 дней');
    expect(ruDays(25), '25 дней');
    expect(ruDays(30), '30 дней');
    expect(ruDays(100), '100 дней');
  });

  test('ruDays keeps the 11-14 exception on every hundred', () {
    expect(ruDays(11), '11 дней');
    expect(ruDays(12), '12 дней');
    expect(ruDays(13), '13 дней');
    expect(ruDays(14), '14 дней');
    expect(ruDays(111), '111 дней');
    expect(ruDays(112), '112 дней');
    expect(ruDays(114), '114 дней');
  });
}
