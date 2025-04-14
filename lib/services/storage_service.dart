import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

/// Сервис для работы с локальным хранилищем
class StorageService {
  // Ключи для SharedPreferences
  static const String keyRed = "led_red";
  static const String keyGreen = "led_green";
  static const String keyBlue = "led_blue";
  static const String keyBrightness = "led_brightness";
  static const String keyTemperature = "last_temperature";
  static const String keyHumidity = "last_humidity";

  /// Сохранение настроек RGB
  Future<void> saveRgbSettings(
    int red,
    int green,
    int blue,
    double brightness,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(keyRed, red);
    await prefs.setInt(keyGreen, green);
    await prefs.setInt(keyBlue, blue);
    await prefs.setDouble(keyBrightness, brightness);
  }

  /// Сохранение RGB данных
  Future<void> saveRgbData(RgbData data) async {
    await saveRgbSettings(
      data.red,
      data.green,
      data.blue,
      data.brightnessValue,
    );
  }

  /// Загрузка настроек RGB
  Future<RgbData> loadRgbSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final red = prefs.getInt(keyRed) ?? 255;
    final green = prefs.getInt(keyGreen) ?? 0;
    final blue = prefs.getInt(keyBlue) ?? 0;
    final brightness = (prefs.getDouble(keyBrightness) ?? 0.8) * 100;

    return RgbData(
      red: red,
      green: green,
      blue: blue,
      brightness: brightness.toInt(),
    );
  }

  /// Сохранение данных сенсоров
  Future<void> saveSensorData(SensorData data) async {
    final prefs = await SharedPreferences.getInstance();

    if (data.temperature > 0) {
      await prefs.setDouble(keyTemperature, data.temperature);
    }

    if (data.humidity > 0) {
      await prefs.setDouble(keyHumidity, data.humidity);
    }
  }

  /// Загрузка последних данных сенсоров
  Future<SensorData> loadLastSensorData() async {
    final prefs = await SharedPreferences.getInstance();

    final temperature = prefs.getDouble(keyTemperature) ?? 0.0;
    final humidity = prefs.getDouble(keyHumidity) ?? 0.0;

    return SensorData(temperature: temperature, humidity: humidity);
  }

  /// Очистка всех настроек
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
