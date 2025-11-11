import 'package:flutter/material.dart';

class InterestOption {
  final String label;
  final IconData icon;
  const InterestOption(this.label, this.icon);
}

const List<InterestOption> commonLikeOptions = [
  InterestOption('Swimming', Icons.pool),
  InterestOption('Drawing', Icons.brush),
  InterestOption('Building Blocks', Icons.extension),
  InterestOption('Animals', Icons.pets),
  InterestOption('Music & Dance', Icons.music_note),
  InterestOption('Space Adventures', Icons.flight),
  InterestOption('Video Games', Icons.sports_esports),
  InterestOption('Cooking/Baking', Icons.restaurant),
  InterestOption('Reading', Icons.menu_book),
  InterestOption('Nature Hikes', Icons.park),
];

const List<InterestOption> commonDislikeOptions = [
  InterestOption('Loud Noises', Icons.volume_off),
  InterestOption('Spiders & Bugs', Icons.bug_report),
  InterestOption('Cleaning Room', Icons.cleaning_services),
  InterestOption('Waking Up Early', Icons.wb_sunny),
  InterestOption('Stormy Weather', Icons.cloud),
  InterestOption('Waiting in Line', Icons.hourglass_empty),
  InterestOption('Sharing Toys', Icons.block),
  InterestOption('Broccoli', Icons.restaurant_menu),
  InterestOption('Getting Muddy', Icons.grass),
  InterestOption('Big Crowds', Icons.groups),
];

const List<InterestOption> commonFearOptions = [
  InterestOption('Dark Rooms', Icons.dark_mode),
  InterestOption('Being Alone', Icons.person),
  InterestOption('Trying New Things', Icons.psychology),
  InterestOption('Loud Storms', Icons.thunderstorm),
  InterestOption('Big Crowds', Icons.groups),
  InterestOption('Speaking Up', Icons.mic_none),
];

const List<InterestOption> commonGoalOptions = [
  InterestOption('Make New Friends', Icons.group_add),
  InterestOption('Be Brave', Icons.shield_outlined),
  InterestOption('Try New Foods', Icons.restaurant),
  InterestOption('Sleep Alone', Icons.bedtime),
  InterestOption('Learn to Share', Icons.share),
  InterestOption('Taking Turns', Icons.loop),
  InterestOption('Be Patient', Icons.hourglass_bottom),
  InterestOption('Handle Losing Well', Icons.videogame_asset),
  InterestOption('New School/Routines', Icons.school),
  InterestOption('Keep Trying', Icons.restart_alt),
];

const List<InterestOption> commonComfortOptions = [
  InterestOption('Teddy Bear', Icons.pets),
  InterestOption('Cozy Blanket', Icons.check_box_outline_blank),
  InterestOption('Favorite Song', Icons.music_note),
  InterestOption('Family Hug', Icons.family_restroom),
  InterestOption('Lucky Charm', Icons.star),
  InterestOption('Deep Breaths', Icons.air),
];
