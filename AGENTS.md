# Story Weaver Agents Guide

## Build/Lint/Test Commands

### Flutter (Frontend)
- **Install deps**: `flutter pub get`
- **Lint**: `flutter analyze`
- **Test all**: `flutter test`
- **Test single**: `flutter test test/specific_test.dart`
- **Build web**: `flutter build web --release`
- **Run**: `flutter run -d chrome`

### Python Backend
- **Setup**: `cd backend && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`
- **Run**: `cd backend && python app.py`
- **Test all**: `cd backend && pytest tests/`
- **Test single**: `cd backend && pytest tests/test_file.py::test_function`

## Code Style Guidelines

### Dart/Flutter
- **Imports**: Relative paths, group by package then local, blank line between groups
- **Quotes**: Double quotes for strings
- **Naming**: camelCase variables/functions, PascalCase classes/widgets, UPPER_SNAKE constants
- **Types**: Use strong typing, `final` for immutable, `const` for compile-time constants
- **Async**: Proper async/await, avoid async gaps
- **Error handling**: Try-catch with specific exceptions, meaningful error messages
- **Documentation**: `///` doc comments for public APIs
- **Widgets**: Use `const` constructors when possible, key props for list items

### Python/Flask
- **Imports**: Standard library first, then third-party, then local (blank lines between)
- **Naming**: snake_case functions/variables, PascalCase classes, UPPER_SNAKE constants
- **Error handling**: Try-except blocks, Flask error handlers for HTTP responses
- **Documentation**: Docstrings for functions/classes
- **Structure**: Routes in app.py, models separate, config via environment variables

### General
- **Commits**: `git add . && git commit -m "feat: descriptive message"` (no push)
- **Security**: Never log/commit secrets, validate inputs, use HTTPS URLs
- **Testing**: Write tests for new features, run tests before commits</content>
<parameter name="filePath">/mnt/c/dev/story-weaver-app/AGENTS.md