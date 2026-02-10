import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A magical animation that shows a "Golden Ticket" (story card) 
/// being stamped and saved to the library.
class GoldenTicketAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final String title;

  const GoldenTicketAnimation({
    super.key,
    required this.onComplete,
    required this.title,
  });

  @override
  State<GoldenTicketAnimation> createState() => _GoldenTicketAnimationState();
}

class _GoldenTicketAnimationState extends State<GoldenTicketAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _cardScale;
  late Animation<double> _cardRotation;
  late Animation<double> _stampScale;
  late Animation<double> _stampOpacity;
  late Animation<Offset> _flyAwayOffset;
  late Animation<double> _flyAwayScale;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // 1. Card pops in (0.0 - 0.3)
    _cardScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
      ),
    );

    _cardRotation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // 2. Stamp slams down (0.4 - 0.6)
    _stampScale = Tween<double>(begin: 3.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.6, curve: Curves.bounceOut),
      ),
    );

    _stampOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.45, curve: Curves.easeIn),
      ),
    );

    // 3. Fly away to library (0.75 - 1.0)
    _flyAwayOffset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.5, -1.5),
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeInOutBack),
      ),
    );

    _flyAwayScale = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            return Transform.translate(
              offset: _flyAwayOffset.value * MediaQuery.of(context).size.width,
              child: Transform.scale(
                scale: _cardScale.value * _flyAwayScale.value,
                child: Transform.rotate(
                  angle: _cardRotation.value,
                  child: _buildStoryTicket(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStoryTicket() {
    return Container(
      width: 300,
      height: 450,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7), // Parchment
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ticket Pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
                itemBuilder: (context, index) => const Icon(Icons.auto_awesome),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.book, size: 80, color: AppColors.primary),
                const SizedBox(height: 24),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Merriweather',
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'A MAGICAL TALE',
                  style: TextStyle(
                    letterSpacing: 4,
                    fontWeight: FontWeight.w300,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                const Divider(color: AppColors.gold, thickness: 2),
                const SizedBox(height: 8),
                const Text(
                  'SAVED TO LIBRARY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),

          // The Gold Seal Stamp
          Center(
            child: Opacity(
              opacity: _stampOpacity.value,
              child: Transform.scale(
                scale: _stampScale.value,
                child: _buildGoldSeal(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldSeal() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gold,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        gradient: const RadialGradient(
          colors: [AppColors.goldLight, AppColors.gold],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 50, color: Colors.white),
            Text(
              'APPROVED',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
