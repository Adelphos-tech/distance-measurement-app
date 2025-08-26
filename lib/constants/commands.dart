class Commands {
  // Security prefix 0x5E
  static const int security = 0x5E;

  static const List<int> inRange = <int>[security, 0x01];
  static const List<int> crossedRange = <int>[security, 0x02];

  static const List<int> enableLed = <int>[security, 0x03];
  static const List<int> disableLed = <int>[security, 0x04];

  static const List<int> enableVibrator = <int>[security, 0x05];
  static const List<int> disableVibrator = <int>[security, 0x06];

  static const List<int> setCustomNamePrefix = <int>[security, 0x11];
}


