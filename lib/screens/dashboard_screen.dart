import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import '../widgets/cart_item.dart';
import '../models/cart_item_model.dart';
import '../services/chromadb_client.dart';
import '../services/cart_service.dart';
import '../services/inventory_service.dart';
import '../services/product_detection_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const DashboardScreen({super.key, required this.cameras});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _DbStatus { unknown, ok, error }

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final ChromaDbClient _chromaClient = ChromaDbClient();
  final ProductDetectionService _detectionService =
      HuggingFaceProxyDetectionService();
  final TextEditingController _ragController = TextEditingController();
  late AnimationController _cursorController;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isSearchingImage = false;
  double _shutterScale = 1.0;
  bool _showZoomSlider = false;
  double _zoomLevel = 1.0;
  double _zoomLevelAtStart = 1.0;
  bool _isSliderPersistent = false;
  Offset _dragStartPos = Offset.zero;
  double _zoomButtonScale = 1.0;
  bool _isHardwareZoomSupported = false;
  double _minHardwareZoom = 1.0;
  double _maxHardwareZoom = 1.0;

  // Cart database service (session-scoped, resets on checkout)
  final CartService _cartService = CartService();
  bool _isCheckingOut = false;
  bool _isCheckoutHovered = false;
  
  // Hover states for premium micro-animations
  bool _isProfileHovered = false;
  bool _isDbStatusHovered = false;
  bool _isNotificationHovered = false;
  bool _isChatHovered = false;
  bool _isVoiceHovered = false;
  bool _isShutterHovered = false;

  late AnimationController _shutterPulseController;

  // DB connectivity state — drives the status pill in the app bar
  _DbStatus _dbStatus = _DbStatus.unknown;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _shutterPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initializeCamera();
    // Listen to cart changes so the widget rebuilds reactively.
    _cartService.addListener(_onCartChanged);
    // Silently check DB status on startup so indicator reflects real state.
    _refreshDbStatus();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    // Use low resolution on mobile: CLIP only needs 224x224px, and high-res
    // captures cause a multi-megabyte JPEG write to disk, adding 2-3s of latency.
    // Web uses in-memory Blobs so resolution has no disk-write overhead there.
    const resolution = kIsWeb ? ResolutionPreset.medium : ResolutionPreset.low;
    _cameraController = CameraController(
      widget.cameras[0],
      resolution,
      enableAudio: false,
      imageFormatGroup: kIsWeb ? null : ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _checkHardwareZoomSupport();
      }
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
    }
  }

  Future<void> _checkHardwareZoomSupport() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final minZoom = await _cameraController!.getMinZoomLevel();
        final maxZoom = await _cameraController!.getMaxZoomLevel();
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
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      try {
        final targetZoom =
            _minHardwareZoom +
            (level - 1.0) * ((_maxHardwareZoom - _minHardwareZoom) / 2.0);
        await _cameraController!.setZoomLevel(
          targetZoom.clamp(_minHardwareZoom, _maxHardwareZoom),
        );
      } catch (e) {
        _isHardwareZoomSupported = false;
        debugPrint("Hardware zoom failed, disabling: $e");
      }
    }
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    _cameraController?.dispose();
    _cursorController.dispose();
    _shutterPulseController.dispose();
    _ragController.dispose();
    super.dispose();
  }

  Future<void> _checkoutCart() async {
    if (_cartService.isEmpty || _isCheckingOut) return;

    final double total = _cartService.totalPrice;

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF001A23).withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: Color(0xFF001A23),
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Confirm Checkout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001A23),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are about to checkout ${_cartService.itemCount} item${_cartService.itemCount == 1 ? '' : 's'} for a total of',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF001A23),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001A23),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        side: const BorderSide(color: Color(0xFFD2E4E6)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF4A5568),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF001A23),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCheckingOut = true);

    // Simulate brief payment processing
    await Future.delayed(const Duration(milliseconds: 800));

    await _cartService.checkout();

    if (!mounted) return;
    setState(() => _isCheckingOut = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Color(0xFFB3EFB2),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Order placed! ₹${total.toStringAsFixed(2)} charged.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF001A23),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _takePictureAndSearch() async {
    if (_isSearchingImage) return;

    setState(() => _isSearchingImage = true);

    try {
      XFile capturedPhoto = XFile('');
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        capturedPhoto = await _cameraController!.takePicture();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text('Camera unavailable. Triggering search anyway!'),
            backgroundColor: Color(0xFF001A23),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final CartItemModel? item = await _detectionService.detectItem(
        capturedPhoto,
      );

      if (item != null && mounted) {
        // Show confirmation sheet — CLIP can confuse similar-looking products
        // (e.g. different Lays flavours). User verifies before cart is updated.
        final confirmed = await _showItemConfirmSheet(item);
        if (confirmed == true && mounted) {
          _cartService.addItem(item);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.fixed,
              content: Text('${item.name} added to cart!'),
              backgroundColor: const Color(0xFF001A23),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (mounted) {
        // Distance exceeded threshold — no confident match found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text(
              'Item not recognized. Try a closer scan.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF001A23),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error taking picture or searching: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: Text(
              'Error searching item',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearchingImage = false);
    }
  }

  /// Shows a confirmation bottom sheet for the detected item.
  /// Returns true if user confirmed, false/null if dismissed.
  Future<bool?> _showItemConfirmSheet(CartItemModel item) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFF3F4F6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Item detected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4A5568),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF001A23),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF001A23),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF001A23),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Not this item',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRagSheet() {
    _ragController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ask Chef RAG',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF001A23),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ragController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Ask anything about the products...',
                    hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                    filled: true,
                    fillColor: const Color(0xFFFFFFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFD2E4E6),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFD2E4E6),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFB3EFB2),
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onSubmitted: (_) {
                    Navigator.pop(ctx);
                    _askChefRag();
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _askChefRag();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF001A23),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Text(
                      'Ask',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _askChefRag() async {
    if (_ragController.text.trim().isEmpty) return;

    final prompt = _ragController.text;
    _ragController.clear();

    final response = await _chromaClient.askChefRag(prompt);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          content: Text(response, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF001A23),
        ),
      );
    }
  }

  /// Silent background check — updates the indicator, no snackbar.
  Future<void> _refreshDbStatus() async {
    final chromaStatus = await _chromaClient.checkConnectivity();
    final supabaseStatus = await InventoryService().checkConnectivity();
    if (!mounted) return;
    final allOk =
        chromaStatus.startsWith('Connected') &&
        supabaseStatus.startsWith('Connected');
    setState(() => _dbStatus = allOk ? _DbStatus.ok : _DbStatus.error);
  }

  Future<void> _checkDbStatus() async {
    // Show a loading snackbar while checking
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.fixed,
        content: Text(
          'Checking database connections...',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF001A23),
        duration: Duration(milliseconds: 800),
      ),
    );

    final chromaStatus = await _chromaClient.checkConnectivity();
    final supabaseStatus = await InventoryService().checkConnectivity();

    if (mounted) {
      final isChromaOk = chromaStatus.startsWith("Connected");
      final isSupabaseOk = supabaseStatus.startsWith("Connected");

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ChromaDB: $chromaStatus',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Supabase: $supabaseStatus',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: (isChromaOk && isSupabaseOk)
              ? const Color(0xFF001A23)
              : const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
      // Also update the indicator
      setState(
        () => _dbStatus = (isChromaOk && isSupabaseOk)
            ? _DbStatus.ok
            : _DbStatus.error,
      );
    }
  }

  void _incrementQuantity(int index) => _cartService.incrementQuantity(index);

  void _decrementQuantity(int index) => _cartService.decrementQuantity(index);

  void _removeItem(int index) => _cartService.removeItem(index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background soft gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE8F1F2),
                    Color(0xFFF1F8F8),
                    Color(0xFFE8F1F2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Colorful glowing gradient bubbles (Orbs)
          Positioned(
            top: 20,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF001A23).withValues(alpha: 0.18),
                    const Color(0xFF001A23).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB3EFB2).withValues(alpha: 0.2),
                    const Color(0xFFB3EFB2).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.transparent),
            ),
          ),
          Column(
            children: [
              _buildCameraViewport(),
              Expanded(child: _buildShoppingZone()),
            ],
          ),
          Positioned(
            bottom: 20,
            left: MediaQuery.of(context).size.width * 0.05,
            right: MediaQuery.of(context).size.width * 0.05,
            child: _buildBottomNavBar(),
          ),
        ],
      ),
    );
  }

  void _showProfileSheet() {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Guest';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF001A23).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF001A23).withValues(alpha: 0.1),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF001A23),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Signed in as',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4A5568),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001A23),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Supabase.instance.client.auth.signOut();
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: SafeArea(
        child: Container(
          height: 72,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF001A23).withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFD2E4E6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _showProfileSheet,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isProfileHovered = true),
                  onExit: (_) => setState(() => _isProfileHovered = false),
                  child: AnimatedScale(
                    scale: _isProfileHovered ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFFFFF),
                        border: Border.all(
                          color: _isProfileHovered
                              ? const Color(0xFFB3EFB2)
                              : const Color(0xFFD2E4E6),
                          width: _isProfileHovered ? 1.8 : 1.0,
                        ),
                        boxShadow: _isProfileHovered
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFB3EFB2).withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          (() {
                            final email =
                                Supabase
                                    .instance
                                    .client
                                    .auth
                                    .currentUser
                                    ?.email ??
                                'U';
                            return email.isNotEmpty
                                ? email[0].toUpperCase()
                                : 'U';
                          })(),
                          style: const TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF001A23),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _checkDbStatus,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isDbStatusHovered = true),
                  onExit: (_) => setState(() => _isDbStatusHovered = false),
                  child: AnimatedScale(
                    scale: _isDbStatusHovered ? 1.04 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _isDbStatusHovered
                                ? const Color(0xFF001A23).withValues(alpha: 0.03)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'DB Status',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF001A23),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 1,
                            height: 12,
                            color: const Color(0xFF001A23).withValues(
                              alpha: 0.12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            switch (_dbStatus) {
                              _DbStatus.ok => 'Live',
                              _DbStatus.error => 'Error',
                              _DbStatus.unknown => 'Checking…',
                            },
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: switch (_dbStatus) {
                                _DbStatus.ok => const Color(0xFFB3EFB2),
                                _DbStatus.error => const Color(0xFFEF4444),
                                _DbStatus.unknown => const Color(0xFF4A5568),
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _isNotificationHovered = true),
                onExit: (_) => setState(() => _isNotificationHovered = false),
                child: AnimatedScale(
                  scale: _isNotificationHovered ? 1.06 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: _isNotificationHovered ? -0.15 : 0,
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.rotate(angle: value, child: child);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFFFFF),
                        border: Border.all(
                          color:
                              _isNotificationHovered
                                  ? const Color(0xFFB3EFB2)
                                  : const Color(0xFFD2E4E6),
                          width: _isNotificationHovered ? 1.8 : 1.0,
                        ),
                        boxShadow:
                            _isNotificationHovered
                                ? [
                                  BoxShadow(
                                    color: const Color(0xFFB3EFB2).withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_none_outlined,
                            color: Color(0xFF001A23),
                            size: 22,
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFB3EFB2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraViewport() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF001A23).withValues(alpha: 0.06),
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
                // FIXED: Correct portrait aspect ratio cropping using FittedBox + AspectRatio
                if (_isCameraInitialized && _cameraController != null)
                  Positioned.fill(
                    child: AnimatedScale(
                      scale: _zoomLevel,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          child: AspectRatio(
                            // Invert landscape aspect ratio constraints for seamless portrait preview paths
                            aspectRatio:
                                1 / _cameraController!.value.aspectRatio,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF001A23),
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
                        color: const Color(0xFFB3EFB2),
                        strokeWidth: 2.0,
                        borderRadius: 16,
                        arcLength: 20,
                      ),
                      child: _isSearchingImage
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    const Color(
                                      0xFFB3EFB2,
                                    ).withValues(alpha: 0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            )
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
                                  activeTrackColor: const Color(0xFFB3EFB2),
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
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
                          Future.delayed(const Duration(milliseconds: 150), () {
                            if (mounted) {
                              setState(() {
                                _zoomButtonScale = 1.0;
                              });
                            }
                          });
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
                              (_zoomLevelAtStart - (dx / 70.0)).clamp(1.0, 3.0);
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
                                  ? const Color(0xFFB3EFB2)
                                  : const Color(
                                      0xFF1A1A1A,
                                    ).withValues(alpha: 0.6),
                              boxShadow: _showZoomSlider
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFB3EFB2,
                                        ).withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              _showZoomSlider ? Icons.zoom_out : Icons.zoom_in,
                              color: _showZoomSlider
                                  ? const Color(0xFF001A23)
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
    );
  }

  Widget _buildShoppingZone() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: const Border(
          top: BorderSide(color: Color(0xFFD2E4E6), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF001A23).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Cart',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001A23),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_cartService.isEmpty) ...[
                    Text(
                      '₹${_cartService.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF001A23),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3EFB2).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_cartService.itemCount} ${_cartService.itemCount == 1 ? 'Item' : 'Items'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF001A23),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOut,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_cartService.isEmpty) ...[
                          const SizedBox(height: 40),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFF001A23,
                                    ).withValues(alpha: 0.05),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Color(0xFF001A23),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Your cart is empty',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF001A23),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Scan an item to add it to your cart',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4A5568),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ] else ...[
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _cartService.items.length,
                            itemBuilder: (context, index) {
                              final item = _cartService.items[index];
                              return Dismissible(
                                key: Key(item.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                onDismissed: (_) => _removeItem(index),
                                child: CartItem(
                                  imageUrl: item.imageUrl,
                                  name: item.name,
                                  details:
                                      "${item.quantity} ${item.quantity == 1 ? 'Item' : 'Items'} • ₹${(item.price * item.quantity).toStringAsFixed(2)}",
                                  quantity: item.quantity,
                                  onIncrement: () => _incrementQuantity(index),
                                  onDecrement: () => _decrementQuantity(index),
                                  onRemove: () => _removeItem(index),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ),
                // ── Checkout Bar ──────────────────────────────────────
                if (!_cartService.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
                    child: _buildCheckoutBar(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF001A23),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF001A23).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isCheckingOut ? null : _checkoutCart,
          borderRadius: BorderRadius.circular(40),
          onHover: (hovered) {
            setState(() {
              _isCheckoutHovered = hovered;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_cartService.itemCount} item${_cartService.itemCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${_cartService.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                _isCheckingOut
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        children: [
                          const Text(
                            'Checkout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.only(
                              left: _isCheckoutHovered ? 10.0 : 6.0,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFFD2E4E6)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF001A23).withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _showRagSheet,
                      onHover: (hovered) => setState(() => _isChatHovered = hovered),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        transform: Matrix4.translationValues(0, _isChatHovered ? -3 : 0, 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              color: Color(0xFF001A23),
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Chat',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF001A23),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 74),
                  Expanded(
                    child: InkWell(
                      onTap: () {},
                      onHover: (hovered) => setState(() => _isVoiceHovered = hovered),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        transform: Matrix4.translationValues(0, _isVoiceHovered ? -3 : 0, 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.mic_none,
                              color: _isVoiceHovered
                                  ? const Color(0xFF001A23)
                                  : const Color(0xFF4A5568),
                              size: 22,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Voice',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isVoiceHovered
                                    ? const Color(0xFF001A23)
                                    : const Color(0xFF4A5568),
                                fontWeight: _isVoiceHovered
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildShutterButton(),
      ],
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _shutterScale = 0.92;
        });
      },
      onTapUp: (_) {
        setState(() {
          _shutterScale = 1.0;
        });
        _takePictureAndSearch();
      },
      onTapCancel: () {
        setState(() {
          _shutterScale = 1.0;
        });
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isShutterHovered = true),
        onExit: (_) => setState(() => _isShutterHovered = false),
        child: AnimatedScale(
          scale: (_isShutterHovered ? 1.06 : 1.0) * _shutterScale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          child: AnimatedBuilder(
            animation: _shutterPulseController,
            builder: (context, child) {
              final pulse = _shutterPulseController.value;
              return Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB3EFB2),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB3EFB2).withValues(
                        alpha: _isShutterHovered ? 0.45 : 0.3 + 0.1 * pulse,
                      ),
                      blurRadius: _isShutterHovered ? 20 : 14 + 6 * pulse,
                      offset: Offset(0, 4 + 2 * pulse),
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Center(
              child: _isSearchingImage
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF001A23),
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF001A23),
                      size: 28,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReticlePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double borderRadius;
  final double arcLength;

  ReticlePainter({
    required this.color,
    required this.strokeWidth,
    required this.borderRadius,
    required this.arcLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;
    final double r = borderRadius;
    final double len = arcLength;

    final pathTL = Path()
      ..moveTo(0, r + len)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(r + len, 0);
    canvas.drawPath(pathTL, paint);

    final pathTR = Path()
      ..moveTo(w - (r + len), 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, r + len);
    canvas.drawPath(pathTR, paint);

    final pathBR = Path()
      ..moveTo(w, h - (r + len))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(w - (r + len), h);
    canvas.drawPath(pathBR, paint);

    final pathBL = Path()
      ..moveTo(r + len, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, h - (r + len));
    canvas.drawPath(pathBL, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
