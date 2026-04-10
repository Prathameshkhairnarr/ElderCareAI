import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/app_logger.dart';
import '../services/prescription_service.dart';

class PrescriptionReaderScreen extends StatefulWidget {
  const PrescriptionReaderScreen({super.key});

  @override
  State<PrescriptionReaderScreen> createState() => _PrescriptionReaderScreenState();
}

class _PrescriptionReaderScreenState extends State<PrescriptionReaderScreen> {
  final ImagePicker _picker = ImagePicker();
  final PrescriptionService _service = PrescriptionService();
  
  File? _image;
  bool _isLoading = false;
  String? _resultText;

  /// Helper to convert simple markdown "**text**" into bold TextSpans.
  List<TextSpan> _parseMarkdownBold(String text, Color textColor) {
    final List<TextSpan> spans = [];
    final parts = text.split('**');
    
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        // This part was enclosed in ** stars, make it bold
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
        ));
      } else {
        // Normal text
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(fontWeight: FontWeight.normal, color: textColor),
        ));
      }
    }
    return spans;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
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
          const SnackBar(content: Text('Failed to pick image!')),
        );
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    AppLogger.info(LogCategory.lifecycle, '[RX UI] Starting analysis for image: ${_image!.path}');
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _service.analyzePrescriptionImage(_image!);
      
      AppLogger.info(LogCategory.lifecycle, '[RX UI] Analysis complete. Success: ${result != null}');
      if (mounted) {
        setState(() {
          _resultText = result ?? "Image clear nahi hai, please clearer photo upload karein.";
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error(LogCategory.lifecycle, '[RX UI] Analysis error: $e');
      if (mounted) {
        setState(() {
          // If the service threw an Exception with a message, show it explicitly.
          final errorMsg = e.toString().replaceAll('Exception: ', '');
          _resultText = "Error: $errorMsg";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.document_scanner_rounded, color: cs.primary),
            const SizedBox(width: 8),
            const Text('Rx Reader'),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'AI Prescription Reader',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Upload a photo of your doctor's prescription and I will explain it to you simply.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: cs.primary,
                        side: BorderSide(color: cs.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Image Preview
              if (_image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.file(
                        _image!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      if (_isLoading)
                        Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.black.withValues(alpha: 0.5),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Processing Indicator
              if (_isLoading && _image == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Result View
              if (_resultText != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                     color: cs.surfaceContainerHighest,
                     borderRadius: BorderRadius.circular(24),
                     border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Doctor Note Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.health_and_safety_rounded, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Doctor Veda says',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Markdown/Formatted Result Text
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            fontFamily: 'Roboto', // Matches default but ensures RichText renders properly
                          ),
                          children: _parseMarkdownBold(
                            _resultText!, 
                            cs.onSurface.withValues(alpha: 0.9)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
