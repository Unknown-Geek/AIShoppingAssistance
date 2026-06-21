import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/order_card.dart';
import 'widgets/profile_skeleton_list.dart';
import 'widgets/profile_header_pill.dart';

class PastOrdersPage extends StatefulWidget {
  const PastOrdersPage({super.key});

  @override
  State<PastOrdersPage> createState() => _PastOrdersPageState();
}

class _PastOrdersPageState extends State<PastOrdersPage> {
  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  final Set<String> _expandedOrderIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Defer database loading slightly to ensure screen transitions are fluid
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _loadOrders();
        }
      });
    });
  }

  Future<void> _loadOrders() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => loading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('user_carts')
          .select()
          .eq('user_id', user.id)
          .ilike('status', 'processed')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          orders = List<Map<String, dynamic>>.from(response);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading orders in PastOrdersPage: $e');
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _toggleExpand(String orderId) {
    setState(() {
      if (_expandedOrderIds.contains(orderId)) {
        _expandedOrderIds.remove(orderId);
      } else {
        _expandedOrderIds.add(orderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background soft visual decoration (radial gradients) matching profile
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.12),
                    theme.colorScheme.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Main Body
          SafeArea(
            child: Column(
              children: [
                // Custom Floating Header Pill
                ProfileHeaderPill(
                  onBackTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Past Orders',
                                style: TextStyle(
                                  fontFamily: theme.textTheme.titleLarge?.fontFamily,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your complete transaction history',
                                style: TextStyle(
                                  fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                                  fontSize: 14,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Past Orders List
                        loading
                            ? const ProfileSkeletonList()
                            : orders.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 96),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 64,
                                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No past orders found',
                                            style: TextStyle(
                                              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    itemCount: orders.length,
                                    itemBuilder: (context, index) {
                                      final order = orders[index];
                                      final orderId = order['id']?.toString() ?? index.toString();
                                      final isExpanded = _expandedOrderIds.contains(orderId);
                                      return OrderCard(
                                        order: order,
                                        isExpanded: isExpanded,
                                        onTap: () => _toggleExpand(orderId),
                                      );
                                    },
                                  ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
