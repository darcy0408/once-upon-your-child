# AGENTS.md - Story Weaver App

## Build/Lint/Test Commands

### Flutter (Frontend)
- **Build**: `flutter pub get` (install deps), `flutter build web --release`
- **Run**: `flutter run -d chrome`
- **Test**: `flutter test` (all tests), `flutter test test/story_complexity_service_test.dart` (single test)
- **Lint**: `flutter analyze`

### Python Backend
- **Install**: `cd backend && pip install -r requirements.txt`
- **Run**: `cd backend && python app.py`
- **Test**: `cd backend && python -m pytest tests/` (all tests), `python -m pytest tests/test_specific.py::TestClass::test_method` (single test)

## Code Style Guidelines

### Dart/Flutter
- **Imports**: Group by type (dart:*, package:*, relative), blank line between groups
- **Naming**: camelCase for variables/functions, PascalCase for classes, UPPER_SNAKE for constants
- **Types**: Use explicit types, prefer `final` for immutables, nullable with `?`
- **Async**: Use `async/await`, handle errors with try/catch blocks
- **Formatting**: Follow flutter_lints (included in analysis_options.yaml)
- **Error Handling**: Use try/catch with specific exception types, log errors appropriately

### Python Backend
- **Imports**: Standard library first, then third-party, then local (blank lines between)
- **Naming**: snake_case for variables/functions, PascalCase for classes
- **Types**: Use type hints where possible
- **Error Handling**: Use try/except with specific exceptions, log with logging module