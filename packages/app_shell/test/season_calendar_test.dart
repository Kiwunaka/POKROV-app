import 'package:flutter_test/flutter_test.dart';
import 'package:pokrov_app_shell/app_shell.dart';
import 'package:pokrov_app_ui/pokrov_app_ui.dart' show PokrovSeason;

void main() {
  PokrovSeason? on(int year, int month, int day, [int hour = 12]) => pokrovSeasonForDate(DateTime(year, month, day, hour));

  test('holiday windows start and end on the agreed days', () {
    final cases = <(int, int, int), PokrovSeason?>{
      (2026, 10, 24): null, (2026, 10, 25): PokrovSeason.halloween, (2026, 11, 1): PokrovSeason.halloween, (2026, 11, 2): null,
      (2026, 12, 14): null, (2026, 12, 15): PokrovSeason.newYear, (2027, 1, 5): PokrovSeason.newYear,
      (2027, 1, 6): PokrovSeason.christmas, (2027, 1, 8): PokrovSeason.christmas, (2027, 1, 9): null,
      (2027, 2, 12): null, (2027, 2, 13): PokrovSeason.valentine, (2027, 2, 14): PokrovSeason.valentine, (2027, 2, 15): null,
      (2027, 2, 21): null, (2027, 2, 22): PokrovSeason.defender, (2027, 2, 23): PokrovSeason.defender, (2027, 2, 24): null,
      (2027, 3, 6): null, (2027, 3, 7): PokrovSeason.womensDay, (2027, 3, 8): PokrovSeason.womensDay, (2027, 3, 9): null,
      (2027, 3, 31): null, (2027, 4, 1): PokrovSeason.aprilFools, (2027, 4, 2): null,
      (2027, 4, 11): null, (2027, 4, 12): PokrovSeason.cosmonautics, (2027, 4, 13): null,
      (2027, 5, 1): null, (2027, 5, 2): PokrovSeason.easter, (2027, 5, 3): PokrovSeason.easter, (2027, 5, 4): null,
      (2027, 5, 7): null, (2027, 5, 8): PokrovSeason.victoryDay, (2027, 5, 9): PokrovSeason.victoryDay, (2027, 5, 10): null,
    };
    cases.forEach((date, season) => expect(on(date.$1, date.$2, date.$3), season, reason: '$date'));
    expect(on(2026, 10, 25, 0), PokrovSeason.halloween);
    expect(on(2026, 11, 1, 23), PokrovSeason.halloween);
  });

  test('Orthodox Easter matches known dates', () {
    expect(orthodoxEaster(2024), DateTime.utc(2024, 5, 5));
    expect(orthodoxEaster(2025), DateTime.utc(2025, 4, 20));
    expect(orthodoxEaster(2026), DateTime.utc(2026, 4, 12));
    expect(orthodoxEaster(2027), DateTime.utc(2027, 5, 2));
    expect(orthodoxEaster(2028), DateTime.utc(2028, 4, 16));
  });

  test('overlaps follow the explicit priority', () {
    expect(on(2026, 4, 12), PokrovSeason.easter, reason: 'Easter wins over 12 April');
    expect(on(2026, 4, 13), PokrovSeason.easter);
    expect(on(2025, 4, 12), PokrovSeason.cosmonautics);
    for (var year = 2000; year <= 2100; year++) {
      expect(on(year, 5, 8), PokrovSeason.victoryDay, reason: '$year');
      expect(on(year, 5, 9), PokrovSeason.victoryDay, reason: '$year');
      final easter = orthodoxEaster(year);
      if (easter.month == 4 && (easter.day == 11 || easter.day == 12)) {
        expect(on(year, 4, 12), PokrovSeason.easter, reason: '$year');
      }
    }
  });

  test('New Year fireworks run only on the night of 31 December', () {
    expect(pokrovNewYearNight(DateTime(2026, 12, 31, 17, 59)), isFalse);
    expect(pokrovNewYearNight(DateTime(2026, 12, 31, 18)), isTrue);
    expect(pokrovNewYearNight(DateTime(2027, 1, 1, 5, 59)), isTrue);
    expect(pokrovNewYearNight(DateTime(2027, 1, 1, 6)), isFalse);
  });
}
