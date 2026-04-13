import sys

file_path = "c:\\dev\\story-weaver-app\\lib\\feelings_wheel_data.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update FeelingDetail class definition
class_search = """class FeelingDetail {
  final String description;
  final List<String> coping;
  final String? emoji;

  const FeelingDetail({
    required this.description,
    required this.coping,
    this.emoji,
  });
}"""

class_replace = """class FeelingDetail {
  final String description;
  final List<String> coping;
  final String? emoji;
  final List<String>? matureCoping;

  const FeelingDetail({
    required this.description,
    required this.coping,
    this.emoji,
    this.matureCoping,
  });

  List<String> copingForAge(int age) {
    if (age >= 12 && matureCoping != null) return matureCoping!;
    return coping;
  }
}"""

# Convert CRLF to LF for reliable matching
content = content.replace('\\r\\n', '\\n')
class_search = class_search.replace('\\r\\n', '\\n')
class_replace = class_replace.replace('\\r\\n', '\\n')

content = content.replace(class_search, class_replace)

# 2. Add matureCoping lists
# Frustrated
content = content.replace('''      ],
      emoji: '😤',''', '''      ],
      matureCoping: [
        'Step back and take a few slow breaths.',
        'Break the problem into smaller parts.',
        'Write down what\\'s blocking you.',
      ],
      emoji: '😤',''')

# Worried
content = content.replace('''      ],
      emoji: '😟',''', '''      ],
      matureCoping: [
        'Practice box breathing (4 in, 4 hold, 4 out, 4 hold).',
        'Write down your worry and challenge it with evidence.',
        'Talk to someone you trust about what\\'s on your mind.',
      ],
      emoji: '😟',''')

# Lonely
content = content.replace('''      ],
      emoji: '😔',''', '''      ],
      matureCoping: [
        'Reach out to one person, even with a simple message.',
        'Spend time in a shared space, even quietly.',
        'Remember that loneliness is temporary and common.',
      ],
      emoji: '😔',''')

# Sad
content = content.replace('''      ],
      emoji: '😢',''', '''      ],
      matureCoping: [
        'Allow yourself to feel it — sadness is valid.',
        'Reach out to someone you trust.',
        'Do one small thing that usually brings you comfort.',
      ],
      emoji: '😢',''')

# Mad
content = content.replace('''      ],
      emoji: '😠',''', '''      ],
      matureCoping: [
        'Remove yourself from the situation for a few minutes.',
        'Use deep breathing to slow your heart rate.',
        'Journal about what triggered the anger.',
      ],
      emoji: '😠',''')

# Scared
content = content.replace('''      ],
      emoji: '😨',''', '''      ],
      matureCoping: [
        'Ground yourself: name 5 things you see, 4 you hear, 3 you feel.',
        'Remind yourself of times you\\'ve faced fear before.',
        'Talk to someone you trust about what feels threatening.',
      ],
      emoji: '😨',''')

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Patch applied")
