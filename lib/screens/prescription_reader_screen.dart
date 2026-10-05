import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../services/app_logger.dart';
import '../services/prescription_service.dart';
import '../services/prescription_history_service.dart';
import '../voice/tts_service.dart';

// ══════════════════════════════════════════════════════
//  PRESCRIPTION READER SCREEN (DOCTOR VEDA)
//  Elder-friendly, sleek modern healthcare aesthetic
// ══════════════════════════════════════════════════════

class PrescriptionReaderScreen extends StatefulWidget {
  const PrescriptionReaderScreen({super.key});

  @override
  State<PrescriptionReaderScreen> createState() => _PrescriptionReaderScreenState();
}

class _PrescriptionReaderScreenState extends State<PrescriptionReaderScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final PrescriptionService _service = PrescriptionService();
  final TtsService _tts = TtsService();

  File? _image;
  bool _isLoading = false;
  String? _resultText;
  bool _isSpeaking = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initTts();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initTts() async {
    try {
      await _tts.initialize();
    } catch (e) {
      AppLogger.warn(LogCategory.lifecycle, '[RX] TTS init warning: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Stop speech if speaking
      if (_isSpeaking) {
        await _tts.stop();
        setState(() => _isSpeaking = false);
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _resultText = null;
        });
        _analyzeImage();
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, 'Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo select nahi ho payi. Dobara koshish karein.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
    }

    AppLogger.info(LogCategory.lifecycle, '[RX UI] Starting analysis for: ${_image!.path}');
    setState(() {
      _isLoading = true;
      _resultText = null;
    });

    try {
      final result = await _service.analyzePrescriptionImage(_image!);

      AppLogger.info(LogCategory.lifecycle, '[RX UI] Analysis complete. Result length: ${result?.length}');
      if (mounted) {
        setState(() {
          _resultText = result ?? 'Image clear nahi hai, kripya dobara clear photo upload karein.';
          _isLoading = false;
        });

        // Check if photo is a valid prescription
        final isInvalidImage = result == null ||
            result.contains('Yeh Doctor Ki Prescription Nahi Hai') ||
            result.contains('Prescription Nahi Hai');

        if (result != null && result.isNotEmpty && !isInvalidImage) {
          final record = PrescriptionRecord(
            id: const Uuid().v4(),
            result: result,
            scannedAt: DateTime.now(),
            imagePath: _image?.path,
          );
          await PrescriptionHistoryService.save(record);
        }
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[RX UI] Analysis error: $e');
      if (mounted) {
        setState(() {
          final errorMsg = e.toString().replaceAll('Exception: ', '');
          _resultText = 'Error: $errorMsg';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleTts() async {
    if (_resultText == null || _resultText!.isEmpty) return;

    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      final cleanText = _cleanTextForTts(_resultText!);
      await _tts.speak(cleanText);
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  String _cleanTextForTts(String raw) {
    // Remove markdown symbols and emojis for clean speech
    return raw
        .replaceAll(RegExp(r'\*\*|\*|#+|_|`'), '')
        .replaceAll(RegExp(r'[🚨⚠️❌📸💊🩺✨📋🕒🥗]'), '')
        .replaceAll(RegExp(r'[\r\n]+'), ' . ')
        .trim();
  }

  void _copyToClipboard() {
    if (_resultText == null) return;
    Clipboard.setData(ClipboardData(text: _resultText!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Prescription ki jankari copy ho gayi!'),
          ],
        ),
        backgroundColor: Colors.teal.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showZoomDialog() {
    if (_image == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.5,
                child: Center(
                  child: Image.file(_image!, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearImage() {
    if (_isSpeaking) {
      _tts.stop();
      _isSpeaking = false;
    }
    setState(() {
      _image = null;
      _resultText = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.document_scanner_rounded, color: cs.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Rx Reader',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_image != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'New Scan',
              onPressed: _clearImage,
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _PrescriptionHistoryScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Hero Introduction Card ──
              _buildHeroCard(cs, isDark),
              const SizedBox(height: 18),

              // ── 2. Action Buttons (Camera & Gallery) ──
              _buildActionCards(cs, isDark),
              const SizedBox(height: 18),

              // ── 3. Image Preview Card (if picked) ──
              if (_image != null) ...[
                _buildImagePreview(cs, isDark),
                const SizedBox(height: 18),
              ],

              // ── 4. Loading / Scanning State ──
              if (_isLoading) ...[
                _buildLoadingCard(cs, isDark),
                const SizedBox(height: 18),
              ],

              // ── 5. Analysis Result ──
              if (_resultText != null && !_isLoading) ...[
                _buildResultSection(cs, isDark),
              ],

              // Extra bottom spacing to avoid bottom nav bar / gesture bar overlap
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGET: HERO BANNER
  // ══════════════════════════════════════════════════════
  Widget _buildHeroCard(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withValues(alpha: isDark ? 0.25 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : cs.primary).withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Doctor Veda AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(Icons.auto_awesome_rounded, color: cs.primary.withValues(alpha: 0.7), size: 18),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            'Prescription Reader',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            'Doctor ki parchi ki photo kheenchein ya upload karein. Doctor Veda dawai, dosage aur niyam saral bhasha mein samjhayengi.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),

          // Feature chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureChip(Icons.edit_note_rounded, 'Handwriting OCR', cs, isDark),
              _buildFeatureChip(Icons.schedule_rounded, 'Dosage Timing', cs, isDark),
              _buildFeatureChip(Icons.volume_up_rounded, 'Audio Reader', cs, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label, ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222244) : cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGET: BALANCED ACTION CARDS (Camera & Gallery)
  // ══════════════════════════════════════════════════════
  Widget _buildActionCards(ColorScheme cs, bool isDark) {
    return Row(
      children: [
        // Camera Button
        Expanded(
          child: _buildActionButton(
            icon: Icons.camera_alt_rounded,
            title: 'Take Photo',
            subtitle: 'Camera se kheenchein',
            isPrimary: true,
            cs: cs,
            isDark: isDark,
            onTap: _isLoading ? null : () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),

        // Gallery Button
        Expanded(
          child: _buildActionButton(
            icon: Icons.photo_library_rounded,
            title: 'From Gallery',
            subtitle: 'Parchi photo chunein',
            isPrimary: false,
            cs: cs,
            isDark: isDark,
            onTap: _isLoading ? null : () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isPrimary,
    required ColorScheme cs,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    final bgColor = isPrimary
        ? (isDark ? const Color(0xFF1E3A5F) : cs.primary.withValues(alpha: 0.15))
        : (isDark ? const Color(0xFF222244) : Colors.white);

    final borderColor = isPrimary
        ? cs.primary.withValues(alpha: 0.4)
        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1));

    final iconColor = isPrimary ? cs.primary : const Color(0xFF9C27B0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: cs.primary.withValues(alpha: 0.15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey.shade400).withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isPrimary ? cs.primary : const Color(0xFF9C27B0)).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGET: IMAGE PREVIEW CARD
  // ══════════════════════════════════════════════════════
  Widget _buildImagePreview(ColorScheme cs, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withValues(alpha: isDark ? 0.3 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.image_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Uploaded Prescription',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Zoom Action
                _buildSmallActionBtn(
                  icon: Icons.zoom_in_rounded,
                  tooltip: 'Zoom In',
                  color: cs.primary,
                  onTap: _showZoomDialog,
                ),
                const SizedBox(width: 6),
                // Retake Action
                _buildSmallActionBtn(
                  icon: Icons.replay_rounded,
                  tooltip: 'Retake',
                  color: cs.onSurface.withValues(alpha: 0.75),
                  onTap: _isLoading ? null : () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 6),
                // Remove Action
                _buildSmallActionBtn(
                  icon: Icons.close_rounded,
                  tooltip: 'Remove',
                  color: Colors.red.shade400,
                  onTap: _isLoading ? null : _clearImage,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Prescription Image Display
          GestureDetector(
            onTap: _showZoomDialog,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  width: double.infinity,
                  color: Colors.black12,
                  child: Image.file(
                    _image!,
                    fit: BoxFit.contain,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text(
                        'Tap to zoom',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGET: LOADING / SCANNING STATE
  // ══════════════════════════════════════════════════════
  Widget _buildLoadingCard(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.document_scanner_rounded, color: cs.primary, size: 36),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Doctor Veda Parchi Padh Rahi Hain...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Doctor ki likhawat, dawaiyon ke naam aur dosage check ho rahe hain...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              backgroundColor: cs.primary.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bas kuch second lagenge...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGET: RESULT SECTION (Doctor Veda's Advice)
  // ══════════════════════════════════════════════════════
  Widget _buildResultSection(ColorScheme cs, bool isDark) {
    final isInvalidPrescription = _resultText!.contains('Yeh Doctor Ki Prescription Nahi Hai') ||
        _resultText!.contains('Prescription Nahi Hai') ||
        _resultText!.startsWith('Error:');

    if (isInvalidPrescription) {
      return _buildInvalidPrescriptionCard(cs, isDark);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Doctor Veda Card Header & Action Bar ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00E676).withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Profile Row
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.health_and_safety_rounded, color: cs.primary, size: 26),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676),
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? const Color(0xFF1A1A2E) : Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Doctor Veda says',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'AI Medical Assistant • Prescription Analysis',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Audio Listen & Copy Bar
              Row(
                children: [
                  // Sunein / Rokein Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleTts,
                      icon: Icon(
                        _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isSpeaking ? 'Awaaz Rokein' : 'Bol Kar Sunayein',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSpeaking ? Colors.red.shade600 : cs.primary,
                        foregroundColor: _isSpeaking ? Colors.white : (isDark ? const Color(0xFF12122A) : Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Copy Button
                  Material(
                    color: isDark ? const Color(0xFF222244) : cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _copyToClipboard,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 18, color: cs.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Structured Result Breakdown Cards ──
        _buildStructuredBreakdownCards(_resultText!, cs, isDark),
        const SizedBox(height: 14),

        // ── Medical Disclaimer Card ──
        _buildDisclaimerCard(cs, isDark),
      ],
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGET: INVALID PRESCRIPTION / ERROR CARD
  // ══════════════════════════════════════════════════════
  Widget _buildInvalidPrescriptionCard(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B1D1D) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dhyan Dijiye',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.amber.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                color: cs.onSurface.withValues(alpha: 0.9),
                fontFamily: 'Inter',
              ),
              children: _parseMarkdownBold(_resultText!, cs.onSurface),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Dobara Clear Photo Kheenchein',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGET: STRUCTURED BREAKDOWN CARDS
  //  Extracts sections and displays them in clean, thematic cards
  // ══════════════════════════════════════════════════════
  Widget _buildStructuredBreakdownCards(String rawResult, ColorScheme cs, bool isDark) {
    // Split text by common section headers or double newlines
    final sections = _extractSections(rawResult);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections.map((sec) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E34) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sec.color.withValues(alpha: isDark ? 0.25 : 0.2),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sec.title.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: sec.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(sec.icon, color: sec.color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sec.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: sec.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: cs.onSurface.withValues(alpha: 0.9),
                    fontFamily: 'Inter',
                  ),
                  children: _parseMarkdownBold(sec.body, cs.onSurface),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════════
  //  WIDGET: DISCLAIMER CARD
  // ══════════════════════════════════════════════════════
  Widget _buildDisclaimerCard(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18182E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aapki Suraksha: Ye jankari sirf samajhne ke liye hai. Dawai ka dose ya timing bina apne doctor ki salah ke kabhi na badlein.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  PARSER: EXTRACT SECTIONS FROM MARKDOWN TEXT
  // ══════════════════════════════════════════════════════
  List<_ParsedSection> _extractSections(String text) {
    final List<_ParsedSection> list = [];
    final lines = text.split('\n');

    String currentTitle = '';
    IconData currentIcon = Icons.medical_services_outlined;
    Color currentColor = const Color(0xFF4FC3F7);
    StringBuffer currentBody = StringBuffer();

    void commit() {
      final bodyStr = currentBody.toString().trim();
      if (bodyStr.isNotEmpty || currentTitle.isNotEmpty) {
        list.add(_ParsedSection(
          title: currentTitle,
          body: bodyStr,
          icon: currentIcon,
          color: currentColor,
        ));
      }
      currentTitle = '';
      currentBody.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.contains('Kya Hua Hai') || line.contains('Possible Condition')) {
        commit();
        currentTitle = 'Kya Hua Hai (Possible Condition)';
        currentIcon = Icons.favorite_rounded;
        currentColor = const Color(0xFF26A69A); // Teal
      } else if (line.contains('Dawaiyaan') || line.contains('Medicines')) {
        commit();
        currentTitle = 'Dawaiyaan (Medicines Identified)';
        currentIcon = Icons.medication_rounded;
        currentColor = const Color(0xFF42A5F5); // Blue
      } else if (line.contains('Kaise Leni Hai') || line.contains('Dosage & Timing')) {
        commit();
        currentTitle = 'Kaise Leni Hai (Dosage & Timing)';
        currentIcon = Icons.access_time_filled_rounded;
        currentColor = const Color(0xFFFFA726); // Amber
      } else if (line.contains('Dhyan Rakhein') || line.contains('Precautions')) {
        commit();
        currentTitle = 'Dhyan Rakhein (Precautions & Tips)';
        currentIcon = Icons.eco_rounded;
        currentColor = const Color(0xFF66BB6A); // Green
      } else if (line.contains('Doctor ko kab dikhayein') || line.contains('Warning')) {
        commit();
        currentTitle = 'Doctor Ko Kab Dikhayein (Warning Signs)';
        currentIcon = Icons.emergency_rounded;
        currentColor = const Color(0xFFEF5350); // Coral / Red
      } else if (line.contains('Disclaimer')) {
        commit();
        currentTitle = 'Disclaimer';
        currentIcon = Icons.info_outline_rounded;
        currentColor = Colors.grey.shade400;
      } else {
        currentBody.writeln(rawLine);
      }
    }
    commit();

    // If no sections were identified, return the whole text as one card
    if (list.isEmpty) {
      list.add(_ParsedSection(
        title: 'Doctor Veda Ki Salah',
        body: text.trim(),
        icon: Icons.health_and_safety_rounded,
        color: const Color(0xFF4FC3F7),
      ));
    }

    return list;
  }

  // ══════════════════════════════════════════════════════
  //  HELPER: MARKDOWN BOLD TO TEXT SPANS
  // ══════════════════════════════════════════════════════
  List<TextSpan> _parseMarkdownBold(String text, Color defaultColor) {
    final List<TextSpan> spans = [];
    final parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        // Enclosed in **
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: defaultColor,
          ),
        ));
      } else {
        // Normal text
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: defaultColor.withValues(alpha: 0.88),
          ),
        ));
      }
    }
    return spans;
  }
}

class _ParsedSection {
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  const _ParsedSection({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });
}

// ══════════════════════════════════════════════════════
//  PRESCRIPTION HISTORY SCREEN (THEME-ALIGNED)
// ══════════════════════════════════════════════════════

class _PrescriptionHistoryScreen extends StatefulWidget {
  const _PrescriptionHistoryScreen();

  @override
  State<_PrescriptionHistoryScreen> createState() => _PrescriptionHistoryScreenState();
}

class _PrescriptionHistoryScreenState extends State<_PrescriptionHistoryScreen> {
  List<PrescriptionRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await PrescriptionHistoryService.getAll();
    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
    }
  }

  Future<void> _deleteRecord(String id) async {
    await PrescriptionHistoryService.delete(id);
    _loadHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription record delete ho gaya')),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saari History Delete Karein?'),
        content: const Text('Saari prescription history delete ho jayegi. Ye wapas nahi aayegi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PrescriptionHistoryService.clearAll();
      _loadHistory();
    }
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rx History'),
        centerTitle: true,
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear All',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.receipt_long_rounded, size: 56, color: cs.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Koi Prescription Nahi Hai',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Aap jo bhi prescription scan karenge, wo yahan dikhegi.',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    return _buildHistoryCard(record, cs, isDark);
                  },
                ),
    );
  }

  Widget _buildHistoryCard(PrescriptionRecord record, ColorScheme cs, bool isDark) {
    final preview = record.result.length > 120
        ? '${record.result.substring(0, 120)}...'
        : record.result;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E34) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: isDark ? 0.2 : 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showFullResult(record),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.medication_rounded, color: cs.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formatDate(record.scannedAt),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                      onPressed: () => _deleteRecord(record.id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  preview.replaceAll('**', ''),
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: cs.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Puri details dekhein',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: cs.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullResult(PrescriptionRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PrescriptionDetailScreen(record: record),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
//  PRESCRIPTION DETAIL SCREEN
// ══════════════════════════════════════════════════════

class _PrescriptionDetailScreen extends StatelessWidget {
  final PrescriptionRecord record;

  const _PrescriptionDetailScreen({required this.record});

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Scanned: ${_formatDate(record.scannedAt)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Image if present
            if (record.imagePath != null && File(record.imagePath!).existsSync()) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(record.imagePath!),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Full Result
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E34) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.primary.withValues(alpha: isDark ? 0.25 : 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SelectableText(
                record.result,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.65,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
