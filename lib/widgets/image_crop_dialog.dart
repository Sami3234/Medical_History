import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// State-of-the-art circular avatar cropper.
/// WhatsApp / Instagram modern dark design with precision circular aperture,
/// smooth pan/pinch zoom, aspect-ratio preservation, and 100% pure in-memory Canvas rendering.
class ImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String title;

  const ImageCropDialog({
    super.key,
    required this.imageBytes,
    this.title = 'Adjust Profile Photo',
  });

  static Future<Uint8List?> show({
    required BuildContext context,
    required Uint8List imageBytes,
    String title = 'Adjust Profile Photo',
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(220),
      builder: (ctx) => ImageCropDialog(imageBytes: imageBytes, title: title),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog>
    with SingleTickerProviderStateMixin {
  static const double _viewSize = 280.0;
  static const double _outputSize = 512.0;

  ui.Image? _decodedImage;
  bool _imageLoaded = false;
  bool _processing = false;

  // Transform states
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _panOffset = Offset.zero;
  int _quarterTurns = 0; // 0, 1, 2, 3 (each 90 deg)

  // Gesture tracking
  double _startScale = 1.0;
  Offset _startPan = Offset.zero;
  Offset _startFocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _decodedImage = frame.image;
        _imageLoaded = true;
        _recalculateBaseScale();
      });
    } catch (e) {
      debugPrint('Image load note: $e');
      if (mounted) {
        setState(() => _imageLoaded = true);
      }
    }
  }

  void _recalculateBaseScale() {
    if (_decodedImage == null) return;
    final isRotated90 = _quarterTurns % 2 != 0;
    final w = isRotated90
        ? _decodedImage!.height.toDouble()
        : _decodedImage!.width.toDouble();
    final h = isRotated90
        ? _decodedImage!.width.toDouble()
        : _decodedImage!.height.toDouble();

    // Base scale so image fills the circular aperture viewport completely (BoxFit.cover)
    _baseScale = math.max(_viewSize / w, _viewSize / h);
    _clampPanOffset();
  }

  void _clampPanOffset() {
    if (_decodedImage == null) return;
    final isRotated90 = _quarterTurns % 2 != 0;
    final w = isRotated90
        ? _decodedImage!.height.toDouble()
        : _decodedImage!.width.toDouble();
    final h = isRotated90
        ? _decodedImage!.width.toDouble()
        : _decodedImage!.height.toDouble();

    final currentW = w * _baseScale * _scale;
    final currentH = h * _baseScale * _scale;

    final maxPanX = math.max(0.0, (currentW - _viewSize) / 2.0);
    final maxPanY = math.max(0.0, (currentH - _viewSize) / 2.0);

    final clampedX = _panOffset.dx.clamp(-maxPanX, maxPanX);
    final clampedY = _panOffset.dy.clamp(-maxPanY, maxPanY);

    _panOffset = Offset(clampedX, clampedY);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startPan = _panOffset;
    _startFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_startScale * details.scale).clamp(1.0, 3.5);
      final delta = details.localFocalPoint - _startFocal;
      _panOffset = _startPan + delta;
      _clampPanOffset();
    });
  }

  void _rotate() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _recalculateBaseScale();
    });
  }

  void _reset() {
    setState(() {
      _quarterTurns = 0;
      _scale = 1.0;
      _panOffset = Offset.zero;
      _recalculateBaseScale();
    });
  }

  void _setScale(double newScale) {
    setState(() {
      _scale = newScale.clamp(1.0, 3.5);
      _clampPanOffset();
    });
  }

  /// High precision in-memory Canvas rendering engine
  Future<void> _applyCrop() async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      final img = _decodedImage;
      if (img == null) {
        if (mounted) Navigator.of(context).pop(widget.imageBytes);
        return;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Clip canvas strictly to circle
      final circlePath = Path()
        ..addOval(const Rect.fromLTWH(0, 0, _outputSize, _outputSize));
      canvas.clipPath(circlePath);

      // Viewport-to-output multiplier
      final double ratio = _outputSize / _viewSize;

      // Translate to output center
      const double centerOut = _outputSize / 2.0;
      canvas.translate(centerOut, centerOut);

      // Apply rotation
      if (_quarterTurns != 0) {
        canvas.rotate(_quarterTurns * (math.pi / 2.0));
      }

      // Apply user pan & zoom
      final isRotated90 = _quarterTurns % 2 != 0;
      final effectivePanX = isRotated90
          ? (_quarterTurns == 1 ? _panOffset.dy : -_panOffset.dy)
          : (_quarterTurns == 2 ? -_panOffset.dx : _panOffset.dx);
      final effectivePanY = isRotated90
          ? (_quarterTurns == 1 ? -_panOffset.dx : _panOffset.dx)
          : (_quarterTurns == 2 ? -_panOffset.dy : _panOffset.dy);

      canvas.translate(effectivePanX * ratio, effectivePanY * ratio);

      final totalScale = _baseScale * _scale * ratio;
      canvas.scale(totalScale, totalScale);

      // Draw original image centered
      final double origW = img.width.toDouble();
      final double origH = img.height.toDouble();
      final src = Rect.fromLTWH(0, 0, origW, origH);
      final dst = Rect.fromLTWH(-origW / 2.0, -origH / 2.0, origW, origH);

      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(
        _outputSize.toInt(),
        _outputSize.toInt(),
      );
      final byteData = await croppedUiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final resultBytes = byteData?.buffer.asUint8List();

      if (mounted) {
        Navigator.of(context).pop(resultBytes ?? widget.imageBytes);
      }
    } catch (e) {
      debugPrint('Crop render note: $e');
      if (mounted) {
        Navigator.of(context).pop(widget.imageBytes);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // Deep Slate 900
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withAlpha(28), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(200),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top Header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withAlpha(45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.crop_rotate_rounded,
                      color: Color(0xFF4ADE80),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Drag to move • Pinch to zoom photo',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.white60,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                    tooltip: 'Cancel',
                    onPressed: _processing
                        ? null
                        : () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 16),

            // ── Circular Viewfinder Viewport ───────────────────────────
            Center(
              child: Container(
                width: _viewSize,
                height: _viewSize,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withAlpha(45),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Loading indicator or interactive photo surface
                      if (!_imageLoaded)
                        const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF4ADE80),
                          ),
                        )
                      else
                        GestureDetector(
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          child: Container(
                            width: _viewSize,
                            height: _viewSize,
                            color: Colors.black,
                            child: CustomPaint(
                              painter: _PhotoCanvasPainter(
                                image: _decodedImage,
                                scale: _scale,
                                baseScale: _baseScale,
                                panOffset: _panOffset,
                                quarterTurns: _quarterTurns,
                              ),
                            ),
                          ),
                        ),

                      // Circular Aperture Overlay Mask with Glowing Border & Grid
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            size: const Size(_viewSize, _viewSize),
                            painter: const _CircleAperturePainter(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Quick Zoom Preset Chips ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPresetChip('Fit', 1.0),
                  const SizedBox(width: 8),
                  _buildPresetChip('1.5x', 1.5),
                  const SizedBox(width: 8),
                  _buildPresetChip('2.0x', 2.0),
                  const SizedBox(width: 8),
                  _buildPresetChip('3.0x', 3.0),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Zoom Slider & Rotation Toolbar ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: Row(
                  children: [
                    // Rotate Button
                    InkWell(
                      onTap: _processing ? null : _rotate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.rotate_right_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Zoom slider
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF4ADE80),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFF4ADE80),
                          overlayColor: const Color(0xFF4ADE80).withAlpha(45),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.5,
                          ),
                          trackHeight: 3.2,
                        ),
                        child: Slider(
                          value: _scale,
                          min: 1.0,
                          max: 3.5,
                          onChanged: _processing ? null : _setScale,
                        ),
                      ),
                    ),

                    // Zoom percentage badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(_scale * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Reset Button
                    InkWell(
                      onTap: _processing ? null : _reset,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white70,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // ── Action Buttons ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      onPressed: _processing
                          ? null
                          : () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withAlpha(50)),
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      onPressed: _processing ? null : _applyCrop,
                      icon: _processing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _processing ? 'Processing...' : 'Apply Photo',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double zoom) {
    final isSelected = (_scale - zoom).abs() < 0.08;
    return InkWell(
      onTap: _processing ? null : () => _setScale(zoom),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF16A34A)
              : Colors.white.withAlpha(16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF4ADE80) : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Canvas painter for the interactive viewport drawing the image with rotation, scale & pan
class _PhotoCanvasPainter extends CustomPainter {
  final ui.Image? image;
  final double scale;
  final double baseScale;
  final Offset panOffset;
  final int quarterTurns;

  const _PhotoCanvasPainter({
    required this.image,
    required this.scale,
    required this.baseScale,
    required this.panOffset,
    required this.quarterTurns,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;

    final center = Offset(size.width / 2.0, size.height / 2.0);
    canvas.save();

    canvas.translate(center.dx, center.dy);

    if (quarterTurns != 0) {
      canvas.rotate(quarterTurns * (math.pi / 2.0));
    }

    final isRotated90 = quarterTurns % 2 != 0;
    final effectivePanX = isRotated90
        ? (quarterTurns == 1 ? panOffset.dy : -panOffset.dy)
        : (quarterTurns == 2 ? -panOffset.dx : panOffset.dx);
    final effectivePanY = isRotated90
        ? (quarterTurns == 1 ? -panOffset.dx : panOffset.dx)
        : (quarterTurns == 2 ? -panOffset.dy : panOffset.dy);

    canvas.translate(effectivePanX, effectivePanY);

    final totalScale = baseScale * scale;
    canvas.scale(totalScale, totalScale);

    final origW = image!.width.toDouble();
    final origH = image!.height.toDouble();
    final src = Rect.fromLTWH(0, 0, origW, origH);
    final dst = Rect.fromLTWH(-origW / 2.0, -origH / 2.0, origW, origH);

    canvas.drawImageRect(
      image!,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PhotoCanvasPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.baseScale != baseScale ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.quarterTurns != quarterTurns ||
        oldDelegate.image != image;
  }
}

/// Circular aperture overlay painter with translucent dark vignette, glowing border, viewfinder brackets & grid
class _CircleAperturePainter extends CustomPainter {
  const _CircleAperturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final radius = (size.width / 2.0) - 8.0;

    // 1. Dark vignette mask outside circle
    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;

    final maskPaint = Paint()
      ..color = Colors.black.withAlpha(175)
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    // 2. Glowing circular aperture ring
    final ringPaint = Paint()
      ..color = const Color(0xFF4ADE80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(center, radius, ringPaint);

    // 3. Rule of Thirds grid inside circle
    final circleClip = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipPath(circleClip);

    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final step = (radius * 2.0) / 3.0;
    final leftX = center.dx - radius;
    final topY = center.dy - radius;

    canvas.drawLine(
      Offset(leftX + step, topY),
      Offset(leftX + step, topY + radius * 2),
      gridPaint,
    );
    canvas.drawLine(
      Offset(leftX + step * 2, topY),
      Offset(leftX + step * 2, topY + radius * 2),
      gridPaint,
    );
    canvas.drawLine(
      Offset(leftX, topY + step),
      Offset(leftX + radius * 2, topY + step),
      gridPaint,
    );
    canvas.drawLine(
      Offset(leftX, topY + step * 2),
      Offset(leftX + radius * 2, topY + step * 2),
      gridPaint,
    );

    canvas.restore();

    // 4. Modern Viewfinder Corner Brackets
    final bracketPaint = Paint()
      ..color = Colors.white.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const bLen = 14.0;
    const bPad = 2.0;

    // Top-left
    canvas.drawLine(
      const Offset(bPad, bPad),
      const Offset(bPad + bLen, bPad),
      bracketPaint,
    );
    canvas.drawLine(
      const Offset(bPad, bPad),
      const Offset(bPad, bPad + bLen),
      bracketPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - bPad, bPad),
      Offset(size.width - bPad - bLen, bPad),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - bPad, bPad),
      Offset(size.width - bPad, bPad + bLen),
      bracketPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(bPad, size.height - bPad),
      Offset(bPad + bLen, size.height - bPad),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(bPad, size.height - bPad),
      Offset(bPad, size.height - bPad - bLen),
      bracketPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - bPad, size.height - bPad),
      Offset(size.width - bPad - bLen, size.height - bPad),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - bPad, size.height - bPad),
      Offset(size.width - bPad, size.height - bPad - bLen),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
