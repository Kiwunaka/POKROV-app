/// Holiday decoration windows by the device's local date. No network: the
/// date always comes from the device clock. Overlaps resolve in the order of
/// the checks below: 9 May, Easter, 12 April, then the fixed holidays.
library;

/// Season ids; they match `PokrovSeason` names in `pokrov_app_ui`.
enum PokrovSeasonId { halloween, newYear, christmas, valentine, defender, womensDay, aprilFools, cosmonautics, easter, victoryDay }

PokrovSeasonId? pokrovSeasonForDate(DateTime now) {
  final value = now.month * 100 + now.day;
  bool within(int from, int to) => value >= from && value <= to;
  if (within(508, 509)) return PokrovSeasonId.victoryDay;
  final sinceEaster = DateTime.utc(now.year, now.month, now.day).difference(orthodoxEaster(now.year)).inDays;
  if (sinceEaster == 0 || sinceEaster == 1) return PokrovSeasonId.easter;
  if (within(412, 412)) return PokrovSeasonId.cosmonautics;
  if (within(401, 401)) return PokrovSeasonId.aprilFools;
  if (within(307, 308)) return PokrovSeasonId.womensDay;
  if (within(222, 223)) return PokrovSeasonId.defender;
  if (within(213, 214)) return PokrovSeasonId.valentine;
  if (within(106, 108)) return PokrovSeasonId.christmas;
  if (within(1215, 1231) || within(101, 105)) return PokrovSeasonId.newYear;
  if (within(1025, 1031) || within(1101, 1101)) return PokrovSeasonId.halloween;
  return null;
}

/// Fireworks on connect: the night from 31 December 18:00 to 1 January 06:00.
bool pokrovNewYearNight(DateTime now) =>
    (now.month == 12 && now.day == 31 && now.hour >= 18) || (now.month == 1 && now.day == 1 && now.hour < 6);

/// Orthodox Easter (Meeus Julian algorithm) as a Gregorian UTC date.
DateTime orthodoxEaster(int year) {
  final d = (19 * (year % 19) + 15) % 30;
  final e = (2 * (year % 4) + 4 * (year % 7) - d + 34) % 7;
  final month = (d + e + 114) ~/ 31;
  final day = (d + e + 114) % 31 + 1;
  final julianOffset = year ~/ 100 - year ~/ 400 - 2;
  return DateTime.utc(year, month, day + julianOffset);
}
