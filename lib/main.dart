import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'services/isar_service.dart';
import 'main_story.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
