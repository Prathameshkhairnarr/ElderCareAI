import 'package:flutter/material.dart';

class AnimatedPalmBackground extends StatefulWidget {
  const AnimatedPalmBackground({Key? key}) : super(key: key);

  @override
  State<AnimatedPalmBackground> createState() => _AnimatedPalmBackgroundState();
}

class _AnimatedPalmBackgroundState extends State<AnimatedPalmBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40), // Very slow majestic pan
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Image spans its full width. We move it from 0 to -width, then snap back.
        return Stack(
          children: [
            // Black deep space background behind everything
            Container(color: const Color(0xFF030712)),
            
            // Loop 1
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 2, // Double width so we can pan half
                child: Transform.translate(
                  offset: Offset(-_controller.value * MediaQuery.of(context).size.width, 0),
                  child: Image.asset(
                    'assets/images/animated_palm.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
            
            // Loop 2 (Appended to the right of Loop 1)
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 2,
                child: Transform.translate(
                  offset: Offset((1.0 - _controller.value) * MediaQuery.of(context).size.width, 0),
                  child: Image.asset(
                    'assets/images/animated_palm.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
