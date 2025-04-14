import 'package:flutter/material.dart';

/// Модель для хранения данных с температурных и влажностных датчиков
class SensorData {
  final double temperature;
  final double humidity;
  final DateTime timestamp;

  /// Конструктор
  SensorData({
    required this.temperature,
    required this.humidity,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Создание из JSON
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Преобразование в JSON
  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// Копирование с изменением
  SensorData copyWith({double? temperature, double? humidity}) {
    return SensorData(
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      timestamp: DateTime.now(),
    );
  }
}

/// Модель для хранения RGB данных и яркости
class RgbData {
  final int red;
  final int green;
  final int blue;
  final int brightness;

  /// Конструктор
  RgbData({
    required this.red,
    required this.green,
    required this.blue,
    required this.brightness,
  });

  /// Создание из JSON
  factory RgbData.fromJson(Map<String, dynamic> json) {
    return RgbData(
      red: (json['red'] as num?)?.toInt() ?? 0,
      green: (json['green'] as num?)?.toInt() ?? 0,
      blue: (json['blue'] as num?)?.toInt() ?? 0,
      brightness: (json['brightness'] as num?)?.toInt() ?? 0,
    );
  }

  /// Создание из Color и brightness
  factory RgbData.fromColor(Color color, double brightness) {
    return RgbData(
      red: color.red,
      green: color.green,
      blue: color.blue,
      brightness: (brightness * 100).toInt(),
    );
  }

  /// Преобразование в JSON
  Map<String, dynamic> toJson() {
    return {'red': red, 'green': green, 'blue': blue, 'brightness': brightness};
  }

  /// Получение цвета
  Color get color => Color.fromRGBO(red, green, blue, 1.0);

  /// Получение яркости
  double get brightnessValue => brightness / 100;
}
