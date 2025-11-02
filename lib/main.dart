import 'package:flutter/material.dart';
import 'main_story.dart';

void main() {
  runApp(const StoryWeaverApp());
}

class StoryWeaverApp extends StatelessWidget {
  const StoryWeaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const StoryCreatorApp();
  }
}
