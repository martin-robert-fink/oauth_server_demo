extension DateTimeX on DateTime {
  int get secondsSinceEpoch => millisecondsSinceEpoch ~/ 1000;
  DateTime fromSecondsSinceEpoch(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}
