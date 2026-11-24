import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/screens/bedtime_wizard_screen.dart';

void main() {
  test('plain goodnight when no buddy arrived', () {
    expect(
      bedtimeDonePrompt(childName: 'Jesse', isMature: false),
      'The end. Goodnight, Jesse. Sweet dreams.',
    );
    expect(
      bedtimeDonePrompt(childName: 'Sam', isMature: true, newBuddyName: ' '),
      "That's the end. Rest well, Sam.",
    );
  });

  test('a new buddy is mentioned as something for tomorrow', () {
    final line = bedtimeDonePrompt(
      childName: 'Jesse',
      isMature: false,
      newBuddyName: 'Moon Owl',
    );
    expect(line, contains('Moon Owl will be waiting to meet you tomorrow'));
    expect(line, endsWith('Goodnight, Jesse. Sweet dreams.'));
  });

  test('older listeners get a plainer line', () {
    expect(
      bedtimeDonePrompt(
        childName: 'Sam',
        isMature: true,
        newBuddyName: 'Atlas',
      ),
      "That's the end. Atlas has joined your companions. Rest well, Sam.",
    );
  });
}
