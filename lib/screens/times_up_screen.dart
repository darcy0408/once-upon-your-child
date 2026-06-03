import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/screen_time_service.dart';
import '../theme/app_theme.dart';

/// Full-screen overlay shown when screen time has ended.
class TimesUpScreen extends StatefulWidget {
  const TimesUpScreen({super.key, required this.reason});

  final String reason;

  @override
  State<TimesUpScreen> createState() => _TimesUpScreenState();
}

class _TimesUpScreenState extends State<TimesUpScreen> {
  final TextEditingController _controller = TextEditingController();

  late int _a;
  late int _b;
  late int _answer;
  String? _error;
  bool _solved = false;

  @override
  void initState() {
    super.initState();
    _generateProblem();
  }

  void _generateProblem() {
    final rng = Random();
    _a = 10 + rng.nextInt(40);
    _b = 10 + rng.nextInt(40);
    _answer = _a + _b;
  }

  Future<void> _check() async {
    final input = int.tryParse(_controller.text.trim());
    if (input == _answer) {
      setState(() {
        _solved = true;
        _error = null;
      });
      await ScreenTimeService.instance.grantExtraTime(15);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    setState(() {
      _error = 'Not quite! Try again.';
    });
    _controller.clear();
    _generateProblem();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBedtime = widget.reason == 'bedtime';
    final title = isBedtime ? 'Bedtime!' : 'Time\'s Up!';
    final message = isBedtime
        ? 'It\'s past bedtime. Time to put the app away and get some sleep!'
        : 'You\'ve used all your screen time for today. Great job playing!';
    final icon = isBedtime ? Icons.bedtime_rounded : Icons.timer_off_rounded;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFFFFD700), size: 80),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Parents: solve to add 15 minutes',
                        style: GoogleFonts.fredoka(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$_a + $_b = ?',
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_solved)
                        Text(
                          'Correct! 15 extra minutes granted.',
                          style: GoogleFonts.fredoka(
                            color: const Color(0xFF4CAF50),
                            fontSize: 16,
                          ),
                        )
                      else ...[
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Answer',
                              hintText: '??',
                              hintStyle: GoogleFonts.fredoka(
                                color: Colors.white.withAlpha(80),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xFFFFD700),
                                ),
                              ),
                            ),
                            onSubmitted: (_) async {
                              await _check();
                            },
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _error!,
                            style: GoogleFonts.fredoka(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: () async {
                            await _check();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                          ),
                          child: Text(
                            'Submit',
                            style: GoogleFonts.fredoka(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
