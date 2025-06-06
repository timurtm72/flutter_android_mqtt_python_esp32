# Мой сайт и резюме:

- [Мой сайт:](https://technocom.site123.me/)
- [Мое резюме инженер программист microcontrollers, PLC:](https://innopolis.hh.ru/resume/782d86d5ff0e9487200039ed1f6f3373384b30)
- [Мое резюме инженер программист Java backend developer (Spring):](https://innopolis.hh.ru/resume/9e3b451aff03fd23830039ed1f496e79587649)
- [Linkedin](https://www.linkedin.com/public-profile/settings?trk=d_flagship3_profile_self_view_public_profile)
  
# Flutter IoT Система Управления и Мониторинга

Мобильное приложение на Flutter для управления и мониторинга IoT системы на базе ESP32-S3. Приложение взаимодействует с MQTT брокером для управления RGB светодиодом и отображения данных с датчика температуры и влажности.

## Архитектура проекта

Проект построен с использованием чистой архитектуры Flutter и включает следующие основные компоненты:

### Экраны
- `LoginScreen` - экран авторизации с сохранением учетных данных
- `HomeScreen` - главный экран с двумя вкладками:
  - Управление RGB светодиодом
  - Мониторинг датчиков

### Сервисы
- `MqttService` - работа с MQTT протоколом:
  - Подключение к брокеру
  - Публикация команд управления RGB
  - Подписка на данные с датчиков
- `StorageService` - локальное хранение данных:
  - Сохранение учетных данных
  - Кэширование настроек RGB
  - Хранение последних показаний датчиков

### Модели данных
- `RgbData` - модель для RGB настроек
- `SensorData` - модель данных с датчиков

## Основные функции

### Управление RGB
- Выбор цвета через ColorPicker
- Регулировка яркости
- Предпросмотр выбранного цвета
- Сохранение настроек локально
- Отправка команд через MQTT

### Мониторинг датчиков
- Отображение текущей температуры и влажности
- Построение графиков за 24 часа
- Автоматическое обновление при получении новых данных
- Сохранение истории локально

## Технические особенности
- Использование `StreamController` для обработки MQTT сообщений
- Автоматическое переподключение к брокеру
- Локальное кэширование данных через `SharedPreferences`
- Визуализация данных с помощью `fl_chart`
- Выбор цвета через `flutter_colorpicker`
- Обработка JSON с помощью встроенных кодеков

## Потоки данных

### Исходящие
- Команды управления RGB через MQTT:
```json
{
  "red": 255,
  "green": 0,
  "blue": 0,
  "brightness": 100
}
```

### Входящие
- Данные с датчиков через MQTT:
```json
{
  "temperature": 25.6,
  "humidity": 45.2
}
```

## Структура проекта
lib/
```plaintext
lib/
├── main.dart
├── home_screen.dart
├── login_screen.dart
├── models/
│   ├── rgb_data.dart
│   └── sensor_data.dart
└── services/
    ├── mqtt_service.dart
    └── storage_service.dart
```

## Связанные проекты
- [Проект прошивки ESP32-S3](https://github.com/timurtm72/esp_idf_esp32_mqtt_android)
- [Версия на Python](https://github.com/timurtm72/python_mqtt_esp32_android)
- [Версия на Kotlin](https://github.com/timurtm72/kotlin_mqtt_esp32_python).

## Требования
- Flutter SDK
- Зависимости:
  - mqtt_client
  - shared_preferences
  - fl_chart
  - flutter_colorpicker

## Установка и запуск
1. Клонировать репозиторий
2. Установить зависимости: `flutter pub get`
3. Запустить приложение: `flutter run`
