import 'package:flutter/material.dart';

import 'interest_options.dart';

class AppearanceColorOption {
  final String label;
  final Color color;
  const AppearanceColorOption(this.label, this.color);
}

const List<AppearanceColorOption> hairColorOptions = [
  AppearanceColorOption('Brown', Color(0xFF8D5524)),
  AppearanceColorOption('Black', Colors.black),
  AppearanceColorOption('Blonde', Color(0xFFF1E2B8)),
  AppearanceColorOption('Red', Color(0xFFB55239)),
  AppearanceColorOption('Auburn', Color(0xFF7D3F1F)),
  AppearanceColorOption('Gray', Color(0xFFB0B0B0)),
  AppearanceColorOption('Silver', Color(0xFFD9D9D9)),
  AppearanceColorOption('Gold', Color(0xFFFFD700)),
  AppearanceColorOption('Bronze', Color(0xFFB08D57)),
  AppearanceColorOption('Rainbow', Color(0xFF9C27B0)),
];

const List<AppearanceColorOption> eyeColorOptions = [
  AppearanceColorOption('Brown', Color(0xFF5B3A29)),
  AppearanceColorOption('Blue', Color(0xFF6EC1E4)),
  AppearanceColorOption('Green', Color(0xFF4CAF50)),
  AppearanceColorOption('Hazel', Color(0xFF8E6C3A)),
  AppearanceColorOption('Gray', Color(0xFF9E9E9E)),
  AppearanceColorOption('Amber', Color(0xFFB4671B)),
  AppearanceColorOption('Silver', Color(0xFFC0C0C0)),
  AppearanceColorOption('Gold', Color(0xFFFFD54F)),
];

const List<InterestOption> outfitPresetOptions = [
  InterestOption('Hero Cape', Icons.flash_on),
  InterestOption('Princess Dress', Icons.face_retouching_natural),
  InterestOption('Sporty Hoodie', Icons.sports_soccer),
  InterestOption('Explorer Gear', Icons.map),
  InterestOption('Space Suit', Icons.rocket_launch),
  InterestOption('Cozy Pajamas', Icons.bedtime),
];
