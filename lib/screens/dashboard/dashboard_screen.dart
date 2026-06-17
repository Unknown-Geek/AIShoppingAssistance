import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'widgets/cart_item.dart';
import '../../models/cart_item_model.dart';
import '../../services/chromadb_client.dart';
import '../../services/cart_service.dart';
import '../../services/inventory_service.dart';
import '../../services/product_detection_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/dashboard_app_bar.dart';
import 'widgets/camera_viewport.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/checkout_bar.dart';
import 'widgets/dashboard_sheets.dart';

class DashboardScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const DashboardScreen({super.key, required this.cameras});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ChromaDbClient _chromaClient = ChromaDbClient();
  final ProductDetectionService _detectionService =
      HuggingFaceProxyDetectionService();
  late AnimationController _cursorController;
  late AnimationController _cartExpandController;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isSearchingImage = false;

  // Cart database service (session-scoped, resets on checkout)
  final CartService _cartService = CartService();
  bool _isCheckingOut = false;

  DbConnectionStatus _dbStatus = DbConnectionStatus.unknown;

  // Background scanning & locking state variables
  Timer? _backgroundScanTimer;
  bool _isCameraBusy = false;
  CartItemModel? _cachedDetectedItem;
  DateTime? _cachedDetectionTime;
  bool _isConfirmSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _cartExpandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _initializeCamera();
    _refreshDbStatus();
    _startBackgroundScanning();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

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
      }
    } catch (e) {
      debugPrint("Camera initialization failed: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopBackgroundScanning();
    _cameraController?.dispose();
    _cursorController.dispose();
    _cartExpandController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startBackgroundScanning();
    } else {
      _stopBackgroundScanning();
    }
  }

  void _startBackgroundScanning() {
    _backgroundScanTimer?.cancel();
    _backgroundScanTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _performBackgroundScan();
    });
    debugPrint("[DashboardScreen] Background scanning started.");
  }

  void _stopBackgroundScanning() {
    _backgroundScanTimer?.cancel();
    _backgroundScanTimer = null;
    debugPrint("[DashboardScreen] Background scanning stopped.");
  }

  Future<void> _performBackgroundScan() async {
    // Requirements:
    // 1. Camera must be initialized and NOT busy
    // 2. Cart must be collapsed (expanded controller value == 0)
    // 3. Shutter must NOT be actively searching/loading a manual scan
    // 4. Confirmation sheet must NOT be open
    if (!_isCameraInitialized || _cameraController == null || _isCameraBusy) return;
    if (_cartExpandController.value > 0.0) return;
    if (_isSearchingImage) return;
    if (_isConfirmSheetOpen) return;

    _isCameraBusy = true;

    XFile? capturedPhoto;
    try {
      capturedPhoto = await _cameraController!.takePicture().timeout(const Duration(seconds: 2));
      
      // Release camera lock early so manual shutter is not blocked by backend API latency
      _isCameraBusy = false;

      final CartItemModel? item = await _detectionService.detectItem(capturedPhoto);

      if (item != null && mounted) {
        setState(() {
          _cachedDetectedItem = item;
          _cachedDetectionTime = DateTime.now();
        });
        debugPrint("[DashboardScreen] Pre-emptive scan detected: ${item.name}");
      }
    } catch (e) {
      _isCameraBusy = false;
      debugPrint("[DashboardScreen] Background scanning exception: $e");
    } finally {
      if (capturedPhoto != null && !kIsWeb) {
        try {
          final file = File(capturedPhoto.path);
          if (await file.exists()) {
            await file.delete();
            debugPrint("[DashboardScreen] Cleaned up background temporary file: ${capturedPhoto.path}");
          }
        } catch (e) {
          debugPrint("[DashboardScreen] Failed to delete temp background file: $e");
        }
      }
    }
  }

  Future<void> _checkoutCart() async {
    if (_cartService.isEmpty || _isCheckingOut) return;

    final double total = _cartService.totalPrice;
    final theme = Theme.of(context);

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
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: theme.colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Confirm Checkout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are about to checkout ${_cartService.itemCount} item${_cartService.itemCount == 1 ? '' : 's'} for a total of',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
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
                        backgroundColor: theme.colorScheme.primary,
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
            Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.secondary,
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
        backgroundColor: theme.colorScheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool _isCacheValid() {
    if (_cachedDetectedItem == null || _cachedDetectionTime == null) return false;
    final age = DateTime.now().difference(_cachedDetectionTime!);
    return age < const Duration(seconds: 3);
  }

  Future<void> _takePictureAndSearch() async {
    if (_isSearchingImage) return;

    if (_isCacheValid()) {
      debugPrint("[DashboardScreen] Using valid pre-emptive scan cache for instant confirm sheet.");
      final item = _cachedDetectedItem!;
      
      // Clear the cache after consuming it to prevent double actions
      setState(() {
        _cachedDetectedItem = null;
        _cachedDetectionTime = null;
        _isConfirmSheetOpen = true;
      });

      final confirmed = await DashboardSheets.showItemConfirmSheet(context, item: item);
      
      if (mounted) {
        setState(() => _isConfirmSheetOpen = false);
        if (confirmed == true) {
          _cartService.addItem(item);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.fixed,
              content: Text('${item.name} added to cart!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
      return;
    }

    // Yield up to 500ms if the camera is busy with a background scan capture
    int retryCount = 0;
    while (_isCameraBusy && retryCount < 10) {
      await Future.delayed(const Duration(milliseconds: 50));
      retryCount++;
    }

    if (_isSearchingImage || _isCameraBusy) {
      debugPrint("[DashboardScreen] Shutter click dropped: camera remains busy.");
      return;
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          content: const Text('Camera is unavailable or not ready.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _isSearchingImage = true);
    _isCameraBusy = true;

    XFile? capturedPhoto;
    try {
      capturedPhoto = await _cameraController!.takePicture().timeout(const Duration(seconds: 2));
      _isCameraBusy = false; // Release lock early once capture succeeds

      final CartItemModel? item = await _detectionService.detectItem(
        capturedPhoto,
      );

      if (item != null && mounted) {
        // Show confirmation sheet — CLIP can confuse similar-looking products
        // (e.g. different Lays flavours). User verifies before cart is updated.
        setState(() => _isConfirmSheetOpen = true);
        final confirmed =
            await DashboardSheets.showItemConfirmSheet(context, item: item);
        if (mounted) {
          setState(() => _isConfirmSheetOpen = false);
        }
        if (confirmed == true && mounted) {
          _cartService.addItem(item);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.fixed,
              content: Text('${item.name} added to cart!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else if (mounted) {
        // Distance exceeded threshold — no confident match found
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.fixed,
            content: const Text(
              'Item not recognized. Try a closer scan.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
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
      _isCameraBusy = false;
      if (capturedPhoto != null && !kIsWeb) {
        try {
          final file = File(capturedPhoto.path);
          if (await file.exists()) {
            await file.delete();
            debugPrint("[DashboardScreen] Cleaned up temporary photo file: ${capturedPhoto.path}");
          }
        } catch (e) {
          debugPrint("[DashboardScreen] Failed to delete temp photo file: $e");
        }
      }
      if (mounted) setState(() => _isSearchingImage = false);
    }
  }



  void _showRagSheet() {
    DashboardSheets.showRagSheet(
      context,
      onSubmitted: _askChefRag,
    );
  }

  Future<void> _askChefRag(String prompt) async {
    final response = await _chromaClient.askChefRag(prompt);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.fixed,
          content: Text(response, style: const TextStyle(color: Colors.white)),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  /// Silent background check — updates the indicator, no snackbar.
  Future<void> _refreshDbStatus() async {
    final results = await Future.wait([
      _chromaClient.checkConnectivity(),
      InventoryService().checkConnectivity(),
    ]);
    final chromaStatus = results[0];
    final supabaseStatus = results[1];

    if (!mounted) return;
    final allOk =
        chromaStatus.startsWith('Connected') &&
        supabaseStatus.startsWith('Connected');
    setState(() => _dbStatus =
        allOk ? DbConnectionStatus.live : DbConnectionStatus.error);
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

    final results = await Future.wait([
      _chromaClient.checkConnectivity(),
      InventoryService().checkConnectivity(),
    ]);
    final chromaStatus = results[0];
    final supabaseStatus = results[1];

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
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
      // Also update the indicator
      setState(
        () => _dbStatus = (isChromaOk && isSupabaseOk)
            ? DbConnectionStatus.live
            : DbConnectionStatus.error,
      );
    }
  }

  void _incrementQuantity(int index) => _cartService.incrementQuantity(index);

  void _decrementQuantity(int index) => _cartService.decrementQuantity(index);

  void _removeItem(int index) => _cartService.removeItem(index);

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'Guest';
    final userInitial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: DashboardAppBar(
        userInitial: userInitial,
        dbStatus: _dbStatus,
        onProfileTap: _showProfileSheet,
        onDbStatusTap: _checkDbStatus,
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background soft gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.scaffoldBackgroundColor,
                    Color.lerp(theme.scaffoldBackgroundColor, Colors.white, 0.5) ?? Colors.white,
                    theme.scaffoldBackgroundColor,
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
                    theme.colorScheme.primary.withValues(alpha: 0.18),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
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
                    theme.colorScheme.secondary.withValues(alpha: 0.2),
                    theme.colorScheme.secondary.withValues(alpha: 0.0),
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
          // AnimatedBuilder isolates redraws to only the camera+cart layout
          // on each animation frame instead of rebuilding the entire screen.
          AnimatedBuilder(
            animation: _cartExpandController,
            builder: (context, _) => Column(
              children: [
                CameraViewport(
                  cameraController: _cameraController,
                  isCameraInitialized: _isCameraInitialized,
                  isSearchingImage: _isSearchingImage,
                  progress: _cartExpandController.value,
                  hasDetectedProduct: _isCacheValid(),
                ),
                Expanded(child: _buildShoppingZone()),
              ],
            ),
          ),
          // Bottom nav bar: pass as static child so it is NOT rebuilt on each frame.
          AnimatedBuilder(
            animation: _cartExpandController,
            builder: (context, child) {
              final progress = _cartExpandController.value;
              return Positioned(
                bottom: 20 - (120 * progress),
                left: MediaQuery.of(context).size.width * 0.05,
                right: MediaQuery.of(context).size.width * 0.05,
                child: Opacity(
                  opacity: (1.0 - progress).clamp(0.0, 1.0),
                  child: IgnorePointer(ignoring: progress > 0.5, child: child!),
                ),
              );
            },
            child: BottomNavBar(
              onChatTap: _showRagSheet,
              onVoiceTap: () {},
              isSearchingImage: _isSearchingImage,
              onShutterTap: _takePictureAndSearch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingZone() {
    return ListenableBuilder(
      listenable: _cartService,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            border: Border(
              top: BorderSide(color: Color(0xFFD2E4E6), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x14001A23),
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle & Header GestureDetector
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  final cameraViewportHeight = MediaQuery.of(context).size.height * 0.33;
                  if (cameraViewportHeight > 0) {
                    _cartExpandController.value = (_cartExpandController.value -
                            (details.primaryDelta ?? 0) / cameraViewportHeight)
                        .clamp(0.0, 1.0);
                  }
                },
                onVerticalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -300) {
                    _cartExpandController.animateTo(
                      1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  } else if (velocity > 300) {
                    _cartExpandController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  } else if (_cartExpandController.value > 0.5) {
                    _cartExpandController.animateTo(
                      1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    _cartExpandController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                onTap: () {
                  if (_cartExpandController.value > 0.5) {
                    _cartExpandController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  } else {
                    _cartExpandController.animateTo(
                      1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Small Drag Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2E4E6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'My Cart',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_cartService.itemCount} ${_cartService.itemCount == 1 ? 'Item' : 'Items'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Expanded(
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
                                          color: theme.colorScheme.primary.withValues(alpha: 0.05),
                                        ),
                                        child: Icon(
                                          Icons.shopping_cart_outlined,
                                          color: theme.colorScheme.primary,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Your cart is empty',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
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
                                RepaintBoundary(
                                  child: ListView.builder(
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
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // ── Checkout Bar ──────────────────────────────────────
                      if (!_cartService.isEmpty)
                        AnimatedBuilder(
                          animation: _cartExpandController,
                          builder: (context, child) => Padding(
                            padding: EdgeInsets.fromLTRB(
                              0,
                              8,
                              0,
                              120 - (100 * _cartExpandController.value),
                            ),
                            child: child!,
                          ),
                          child: CheckoutBar(
                            totalPrice: _cartService.totalPrice,
                            isCheckingOut: _isCheckingOut,
                            onCheckout: _checkoutCart,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProfileSheet() {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Guest';
    DashboardSheets.showProfileSheet(
      context,
      email: email,
      onSignOut: () async {
        await Supabase.instance.client.auth.signOut();
      },
    );
  }
}
