import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../voice/child_voice_controller.dart';
import '../voice/voice_controller.dart' show VoiceState;

class MyBuddyScreen extends StatefulWidget {
  const MyBuddyScreen({Key? key}) : super(key: key);

  @override
  State<MyBuddyScreen> createState() => _MyBuddyScreenState();
}

class _MyBuddyScreenState extends State<MyBuddyScreen> with SingleTickerProviderStateMixin {
  final ChildVoiceController _voice = ChildVoiceController();
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoiceUpdate);

    // Continuous flow animation to drive the Siri-like plasma physics
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voice.speakGreeting();
    });
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceUpdate);
    _voice.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _onVoiceUpdate() {
    if (mounted) setState(() {});
    
    // Smoothly adjust flow speed based on state
    if (_voice.state == VoiceState.listening || _voice.state == VoiceState.processing) {
       _anim.duration = const Duration(milliseconds: 1200); // Fast fluid motion
       _anim.repeat();
    } else {
       _anim.duration = const Duration(seconds: 4); // Slow idle drift
       _anim.repeat();
    }
  }

  void _handleOrbTap() {
    _voice.onMicTap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A10),
      body: Stack(
        children: [
          _buildAmbientBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const Spacer(flex: 3),
                
                // Central Siri-like 3D Plasma Orb
                GestureDetector(
                  onTap: _handleOrbTap,
                  child: _buildSiriOrb(),
                ),
                
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: _buildTranscriptGlassBox(),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Text(
                    _voice.state == VoiceState.idle 
                      ? "TAP ORB TO SPEAK" 
                      : "TAP TO STOP",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3), 
                      fontSize: 12, 
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF3B82F6).withOpacity(0.08)),
          ),
        ),
        Positioned(
          bottom: -150,
          right: -50,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF8B5CF6).withOpacity(0.08)),
          ),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () {
              _voice.forceReset();
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('My Buddy', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              Text('Always here for you', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: _voice.hasError ? Colors.redAccent : (_voice.state == VoiceState.idle ? Colors.white24 : Colors.greenAccent),
              boxShadow: _voice.state == VoiceState.idle || _voice.hasError ? [] : [
                BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 10)
              ]
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _voice.state.name.toUpperCase(),
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  // Exact reproduction of Siri's beautiful flowing plasma sphere
  Widget _buildSiriOrb() {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final state = _voice.state;
        
        // Premium Apple Siri aesthetic colors
        Color color1 = const Color(0xFF3B82F6); // Deep Blue
        Color color2 = const Color(0xFFEC4899); // Magenta Pink
        Color color3 = const Color(0xFF00E5FF); // Neon Cyan
        Color color4 = const Color(0xFF8B5CF6); // Purple
        
        if (state == VoiceState.listening) {
          color1 = const Color(0xFF10B981); // Emerald Green
          color2 = const Color(0xFF14B8A6); // Teal
          color3 = const Color(0xFF00E5FF); // Cyan
          color4 = const Color(0xFF3B82F6); // Blue
        } else if (state == VoiceState.processing) {
          color1 = const Color(0xFFF59E0B); // Amber Yellow
          color2 = const Color(0xFFEF4444); // Crimson Red
          color3 = const Color(0xFFEC4899); // Pink
          color4 = const Color(0xFF8B5CF6); // Deep Purple
        }

        // Time variable for trigonometry driven organic physics
        final t = _anim.value * 2 * math.pi;
        
        // Fluid orbital offsets (figures of 8 and circular paths)
        final x1 = math.cos(t) * 20;
        final y1 = math.sin(t) * 20;
        final x2 = math.cos(t + math.pi) * 25;
        final y2 = math.sin(t * 1.5) * 15;
        final x3 = math.cos(t * 1.2 + math.pi/2) * 30;
        final y3 = math.sin(t * 0.8) * 25;

        return Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base background glow shadow (aura)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, 
                    boxShadow: [
                      BoxShadow(color: color1.withOpacity(0.3), blurRadius: 80, spreadRadius: 10),
                      BoxShadow(color: color2.withOpacity(0.1), blurRadius: 100, spreadRadius: 30)
                    ]
                  ),
                ),
                
                // Perfect 3D Clipped Globe containing the fluid physics
                ClipOval(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dark core to make the neon colors pop vibrantly and look like deep space
                        Container(color: const Color(0xFF090A10)),

                        // Blob 1 (Blue/Pink Gradient)
                        Transform.translate(
                          offset: Offset(x1, y1),
                          child: Transform.rotate(
                            angle: t,
                            child: Container(
                              width: 170, height: 170,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(85),
                                gradient: LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                              ),
                            ),
                          ),
                        ),
                        
                        // Blob 2 (Cyan/Purple Gradient moving paradoxically)
                        Transform.translate(
                          offset: Offset(x2, y2),
                          child: Transform.rotate(
                            angle: -t * 1.5,
                            child: Container(
                              width: 180, height: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(90),
                                gradient: LinearGradient(colors: [color3, color4], begin: Alignment.bottomLeft, end: Alignment.topRight),
                              ),
                            ),
                          ),
                        ),
                        
                        // Blob 3 (Pink/Blue dynamic core)
                        Transform.translate(
                          offset: Offset(x3, y3),
                          child: Transform.rotate(
                            angle: t * 0.8,
                            child: Container(
                              width: 150, height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(85),
                                gradient: LinearGradient(colors: [color2, color1], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                              ),
                            ),
                          ),
                        ),
                        
                        // Moderate Backdrop filter as requested
                        // This blends the shapes together smoothly to form dense glowing plasma
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(color: Colors.white.withOpacity(0.01)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // High-End Frosted Glass Surface Highlight (Curvature reflection)
                // This gives the perfect spherical illusion over the clipped liquid
                Container(
                   width: 200, height: 200,
                   decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                      gradient: RadialGradient(
                        colors: [Colors.white.withOpacity(0.1), Colors.transparent],
                        stops: const [0.0, 0.4],
                        center: const Alignment(-0.3, -0.6), // Top-left specular highlight reflection
                        radius: 0.8
                      ),
                      boxShadow: [
                         BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, spreadRadius: -5, offset: const Offset(0, 5))
                      ]
                   )
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildTranscriptGlassBox() {
    String textToShow = "";
    
    if (_voice.hasError) {
      textToShow = _voice.errorMessage;
    } else if (_voice.isListening) {
      textToShow = _voice.transcript.isEmpty ? "Listening to you..." : '"${_voice.transcript}"';
    } else if (_voice.isProcessing) {
      textToShow = "Thinking...";
    } else if (_voice.isSpeaking) {
      textToShow = '"${_voice.response}"';
    } else {
      textToShow = _voice.response.isNotEmpty ? '"${_voice.response}"' : "Hi! I am your AI buddy. What's on your mind?";
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              textToShow,
              key: ValueKey<String>(textToShow),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _voice.state == VoiceState.listening ? Colors.white70 : Colors.white,
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
