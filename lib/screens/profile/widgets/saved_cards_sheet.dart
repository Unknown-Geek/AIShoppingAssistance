import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedCardsSheet extends StatefulWidget {
  const SavedCardsSheet({super.key});

  @override
  State<SavedCardsSheet> createState() => _SavedCardsSheetState();
}

class _SavedCardsSheetState extends State<SavedCardsSheet> {
  List<Map<String, String>> cards = [];
  bool loading = true;
  bool showAddForm = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('saved_payment_cards');
      if (saved != null) {
        final decoded = List<dynamic>.from(jsonDecode(saved));
        final loadedCards = decoded
            .map((e) => Map<String, String>.from(e))
            .where((card) => card['number'] != '4111 2222 3333 4242')
            .toList();
        if (loadedCards.length != decoded.length) {
          await prefs.setString('saved_payment_cards', jsonEncode(loadedCards));
        }
        setState(() {
          cards = loadedCards;
          loading = false;
        });
      } else {
        setState(() {
          cards = [];
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cards: $e');
      setState(() => loading = false);
    }
  }

  Future<void> _saveNewCard() async {
    if (!_formKey.currentState!.validate()) return;

    final newCard = {
      'holder': _nameController.text.trim(),
      'number': _numberController.text.trim(),
      'expiry': _expiryController.text.trim(),
      'type': _numberController.text.startsWith('5') ? 'Mastercard' : 'Visa',
      'color': cards.length % 2 == 0 ? 'primary' : 'secondary',
    };

    setState(() {
      cards.add(newCard);
      showAddForm = false;
    });

    // Clear fields
    _nameController.clear();
    _numberController.clear();
    _expiryController.clear();
    _cvvController.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_payment_cards', jsonEncode(cards));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card added successfully!'),
            backgroundColor: Color(0xFF006B70),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving card: $e');
    }
  }

  Future<void> _deleteCard(int index) async {
    setState(() {
      cards.removeAt(index);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_payment_cards', jsonEncode(cards));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card removed.'),
            backgroundColor: Color(0xFF001A23),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting card: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Indicator
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    showAddForm ? 'Add New Card' : 'Saved Cards',
                    style: TextStyle(
                      fontFamily: theme.textTheme.titleLarge?.fontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF001A23),
                    ),
                  ),
                  if (!showAddForm)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF006B70), size: 28),
                      onPressed: () {
                        setState(() => showAddForm = true);
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 24),
                      onPressed: () {
                        setState(() => showAddForm = false);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (showAddForm)
                _buildAddCardForm(theme)
              else if (cards.isEmpty)
                _buildEmptyState(theme)
              else
                _buildCardsList(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.credit_card_off_rounded,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No saved cards found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() => showAddForm = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add a Card', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006B70),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsList(ThemeData theme) {
    return Column(
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final card = entry.value;
        final isPrimary = card['color'] == 'primary';
        final isVisa = card['type'] == 'Visa';

        // Format number (mask first 12 digits)
        final rawNum = card['number'] ?? '';
        final cleanNum = rawNum.replaceAll(' ', '');
        final last4 = cleanNum.length >= 4 ? cleanNum.substring(cleanNum.length - 4) : '****';
        final maskedNum = '••••  ••••  ••••  $last4';

        return Dismissible(
          key: Key(rawNum + index.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.only(right: 20),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: Colors.redAccent.shade100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
          ),
          onDismissed: (_) => _deleteCard(index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(24),
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: isPrimary
                    ? [const Color(0xFF001A23), const Color(0xFF006B70)]
                    : [const Color(0xFF1E293B), const Color(0xFF475569)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isPrimary ? const Color(0xFF006B70) : const Color(0xFF1E293B)).withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      Icons.contactless_outlined,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 24,
                    ),
                    Text(
                      isVisa ? 'VISA' : 'mastercard',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontStyle: isVisa ? FontStyle.italic : FontStyle.normal,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                Text(
                  maskedNum,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CARDHOLDER',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card['holder']?.toUpperCase() ?? 'GUEST',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'EXPIRES',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          card['expiry'] ?? 'MM/YY',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddCardForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            style: const TextStyle(color: Color(0xFF001A23)),
            decoration: _inputDecoration('Cardholder Name', Icons.person_outline_rounded),
            validator: (val) => val == null || val.trim().isEmpty ? 'Please enter name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _numberController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Color(0xFF001A23)),
            decoration: _inputDecoration('Card Number', Icons.credit_card_outlined),
            validator: (val) {
              if (val == null || val.trim().replaceAll(' ', '').length < 15) {
                return 'Please enter valid card number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  style: const TextStyle(color: Color(0xFF001A23)),
                  decoration: _inputDecoration('Expiry (MM/YY)', Icons.calendar_today_outlined),
                  validator: (val) {
                    if (val == null || !val.contains('/') || val.length < 5) {
                      return 'Use MM/YY';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF001A23)),
                  decoration: _inputDecoration('CVV', Icons.lock_outline_rounded),
                  validator: (val) {
                    if (val == null || val.length < 3) {
                      return 'Enter CVV';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveNewCard,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF001A23),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: const Text('Save Card', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: const Color(0xFF006B70), size: 20),
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF006B70), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
