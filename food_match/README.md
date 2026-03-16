# FoodMatch — Flutter Mobile App

Мобильное приложение для совместного выбора блюд парой через механику свайпов.

## Стек
- Flutter / Dart
- Provider (state management)
- go_router (навигация)
- Backend: Node.js + Express + MongoDB (отдельный репозиторий)

## Запуск

### Требования
- Flutter SDK >= 3.8.0
- Dart SDK >= 3.8.0
- Запущенный бэкенд FoodMatch

### Установка
```bash
git clone <repo-url>
cd food_match
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Запуск
```bash
# Android эмулятор (бэкенд на localhost:3000)
flutter run

# Chrome
flutter run -d chrome

# iOS симулятор
flutter run -d ios
```

### Настройка API
Адрес бэкенда настраивается в `lib/core/constants/api_constants.dart`.

## Тесты
```bash
flutter test
flutter analyze
```

## Структура проекта
```text
lib/
├── main.dart                  # Точка входа
├── app.dart                   # MaterialApp + тема
├── core/                      # Константы, тема, утилиты
├── data/                      # Модели, репозитории, API
├── features/                  # Экраны и логика по фичам
├── shared/                    # Переиспользуемые виджеты
└── shell/                     # MainShell + BottomNavigation
```

## Экраны
- Login / Register — авторизация по JWT
- Connect Couple — создание/присоединение к паре
- Swipes — свайп карточек блюд (like/dislike)
- Matches — совместные совпадения пары
- Recipe Detail — рецепт блюда
- Add Dish — добавление своего блюда
- Profile — профиль + управление парой
