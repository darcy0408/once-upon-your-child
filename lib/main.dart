import 'package:flutter/material.dart';
import 'services/isar_service.dart';
import 'main_story.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarService.initialize();
  runApp(const StoryWeaverApp());
}

class StoryWeaverApp extends StatelessWidget {
  const StoryWeaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoryCreatorApp();
  }
}
