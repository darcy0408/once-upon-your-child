import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'main_story.dart';
import 'services/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final docsDir = await getApplicationDocumentsDirectory();
  await IsarService.initialize(directoryPath: docsDir.path);
  runApp(const StoryWeaverApp());
}

class StoryWeaverApp extends StatelessWidget {
  const StoryWeaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoryCreatorApp();
  }
}
