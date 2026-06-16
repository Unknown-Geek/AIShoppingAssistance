import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_wrapper.dart';
import 'services/cart_service.dart';
import 'services/inventory_service.dart';
import 'config/config.dart';

List<CameraDescription> cameras = [];

// ---------------------------------------------------------------------------
// Active brand — swap this line to change the entire app's look and feel.
// e.g. BrandConfig.lulu() | BrandConfig.carrefour() | BrandConfig.qless()
// ---------------------------------------------------------------------------
final BrandConfig _activeBrand = BrandConfig.qless();

Future<void> main() async {
  BrandConfig.active = _activeBrand;
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera initialization error: $e');
  }

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Could not load .env file: $e');
  }

  // Initialize Supabase using values from .env
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  // Pre-load local product catalog and cart session in parallel before rendering.
  await Future.wait([
    InventoryService().initLocalCatalog(),
    CartService().load(),
  ]);

  runApp(MainApp(cameras: cameras));
}

class MainApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MainApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _activeBrand.identity.appName,
      debugShowCheckedModeBanner: false,
      theme: _activeBrand.buildTheme(),
      home: AuthWrapper(cameras: cameras),
    );
  }
}
