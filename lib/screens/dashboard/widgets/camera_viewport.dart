import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'reticle_painter.dart';
import 'scanning_overlay.dart';

class CameraViewport extends StatefulWidget {
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final bool isSearchingImage;
  final double progress;
  final bool hasDetectedProduct;

  const CameraViewport({
    super.key,
    required this.cameraController,
    required this.isCameraInitialized,
    required this.isSearchingImage,
    required this.progress,
    required this.hasDetectedProduct,
  });

  @override
  State<CameraViewport> createState() => _CameraViewportState();
}

class _CameraViewportState extends State<CameraViewport> {
  double _zoomLevel = 1.0;
  bool _showZoomSlider = false;
  bool _isSliderPersistent = false;
  double _zoomButtonScale = 1.0;
  Offset _dragStartPos = Offset.zero;
  double _zoomLevelAtStart = 1.0;

  bool _isHardwareZoomSupported = false;
  double _minHardwareZoom = 1.0;
  double _maxHardwareZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _checkHardwareZoomSupport();
  }

  @override
  void didUpdateWidget(CameraViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraController != widget.cameraController ||
        oldWidget.isCameraInitialized != widget.isCameraInitialized) {
      _checkHardwareZoomSupport();
    }
  }

  Future<void> _checkHardwareZoomSupport() async {
    if (widget.cameraController != null && widget.isCameraInitialized) {
      try {
        final minZoom = await widget.cameraController!.getMinZoomLevel();
        final maxZoom = await widget.cameraController!.getMaxZoomLevel();
        if (maxZoom > minZoom) {
          if (mounted) {
            setState(() {
              _minHardwareZoom = minZoom;
              _maxHardwareZoom = maxZoom;
              _isHardwareZoomSupported = true;
            });
          }
        }
      } catch (e) {
        debugPrint("Hardware zoom not supported: $e");
      }
    }
  }

  Future<void> _updateHardwareZoom(double level) async {
    if (_isHardwareZoomSupported &&
        widget.cameraController != null &&
        widget.isCameraInitialized) {
      try {
        final targetZoom =
            _minHardwareZoom +
            (level - 1.0) * ((_maxHardwareZoom - _minHardwareZoom) / 2.0);
        await widget.cameraController!.setZoomLevel(
          targetZoom.clamp(_minHardwareZoom, _maxHardwareZoom),
        );
      } catch (e) {
        _isHardwareZoomSupported = false;
        debugPrint("Hardware zoom failed, disabling: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Keep preview in tree but collapsed visually when expanded (progress goes to 1.0)
    return ClipRect(
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: (1.0 - widget.progress).clamp(0.0, 1.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.33,
                color: const Color(0xFF1A1A1A),
                child: Stack(
                  children: [
                    if (widget.isCameraInitialized &&
                        widget.cameraController != null)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: AnimatedScale(
                            scale: _zoomLevel,
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOut,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                child: AspectRatio(
                                  aspectRatio:
                                      1 /
                                      widget
                                          .cameraController!
                                          .value
                                          .aspectRatio,
                                  child: CameraPreview(
                                    widget.cameraController!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFF1A1A1A),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),

                    // Scanning Reticle Overlay
                    Center(
                      child: SizedBox(
                        width: 180.0,
                        height: 180.0,
                        child: CustomPaint(
                          painter: ReticlePainter(
                            color: widget.hasDetectedProduct
                                ? const Color(
                                    0xFF34D399,
                                  ) // Dynamic vibrant green feedback
                                : theme.colorScheme.secondary,
                            strokeWidth: 2.0,
                            borderRadius: 16,
                            arcLength: 20,
                          ),
                          child: widget.isSearchingImage
                              ? const ScanningOverlay()
                              : null,
                        ),
                      ),
                    ),

                    // Zoom Level HUD Overlay
                    Center(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _showZoomSlider ? 1.0 : 0.0,
                          curve: Curves.easeInOut,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1A1A1A,
                              ).withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              '${_zoomLevel.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Zoom Button & Slider
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _showZoomSlider ? 1.0 : 0.0,
                            curve: Curves.easeInOut,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              width: _showZoomSlider ? 140 : 0,
                              height: 32,
                              margin: EdgeInsets.only(
                                right: _showZoomSlider ? 8 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1A1A1A,
                                ).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: OverflowBox(
                                minWidth: 0,
                                maxWidth: 140,
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 140,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor:
                                          theme.colorScheme.secondary,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      trackHeight: 2,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 12,
                                          ),
                                    ),
                                    child: Slider(
                                      value: _zoomLevel,
                                      min: 1.0,
                                      max: 3.0,
                                      onChanged: (val) {
                                        setState(() {
                                          _zoomLevel = val;
                                        });
                                        _updateHardwareZoom(val);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSliderPersistent = !_isSliderPersistent;
                                _showZoomSlider = _isSliderPersistent;
                                _zoomButtonScale = 1.15;
                              });
                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () {
                                  if (mounted) {
                                    setState(() {
                                      _zoomButtonScale = 1.0;
                                    });
                                  }
                                },
                              );
                            },
                            onLongPressStart: (details) {
                              setState(() {
                                _showZoomSlider = true;
                                _zoomButtonScale = 1.25;
                                _dragStartPos = details.globalPosition;
                                _zoomLevelAtStart = _zoomLevel;
                              });
                            },
                            onLongPressMoveUpdate: (details) {
                              final double dx =
                                  details.globalPosition.dx - _dragStartPos.dx;
                              final double newZoom =
                                  (_zoomLevelAtStart - (dx / 70.0)).clamp(
                                    1.0,
                                    3.0,
                                  );
                              setState(() {
                                _zoomLevel = newZoom;
                              });
                              _updateHardwareZoom(newZoom);
                            },
                            onLongPressEnd: (details) {
                              setState(() {
                                _zoomButtonScale = 1.0;
                                if (!_isSliderPersistent) {
                                  _showZoomSlider = false;
                                }
                              });
                            },
                            child: AnimatedScale(
                              scale: _zoomButtonScale,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutBack,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _showZoomSlider
                                      ? theme.colorScheme.secondary
                                      : const Color(
                                          0xFF1A1A1A,
                                        ).withValues(alpha: 0.6),
                                  boxShadow: _showZoomSlider
                                      ? [
                                          BoxShadow(
                                            color: theme.colorScheme.secondary
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  _showZoomSlider
                                      ? Icons.zoom_out
                                      : Icons.zoom_in,
                                  color: _showZoomSlider
                                      ? theme.colorScheme.primary
                                      : Colors.white,
                                  size: 18,
                                ),
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
          ),
        ),
      ),
    );
  }
}
