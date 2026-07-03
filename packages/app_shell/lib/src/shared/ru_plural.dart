part of pokrov_app_shell;

/// Formats [count] with the correct Russian form of the word «день».
///
/// Follows standard Russian plural rules, including the 11-14 exception:
/// 1 день, 2 дня, 5 дней, 11 дней, 14 дней, 21 день, 22 дня, 25 дней.
String ruDays(int count) {
  final magnitude = count.abs();
  final rem100 = magnitude % 100;
  final rem10 = magnitude % 10;
  final String word;
  if (rem100 >= 11 && rem100 <= 14) {
    word = 'дней';
  } else if (rem10 == 1) {
    word = 'день';
  } else if (rem10 >= 2 && rem10 <= 4) {
    word = 'дня';
  } else {
    word = 'дней';
  }
  return '$count $word';
}
