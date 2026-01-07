import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runrank/services/user_service.dart';
import 'package:runrank/services/payment_service.dart';
import 'package:runrank/services/runners_banquet_service.dart';

class RunnersBanquetPage extends StatefulWidget {
  final String? eventId;
  final String? eventTitle;

  const RunnersBanquetPage({super.key, this.eventId, this.eventTitle});

  @override
  State<RunnersBanquetPage> createState() => _RunnersBanquetPageState();
}

class _RunnersBanquetPageState extends State<RunnersBanquetPage> {
  bool _loading = true;
  bool _isAdmin = false;

  final _optionLabels = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  int _selectedOptionIndex = -1;
  int _partnerOptionIndex = -1;
  int _otherOptionIndex = -1;
  int _memberQuantity = 1;
  int _partnerQuantity = 0;
  int _otherQuantity = 0;

  final _memberPriceController = TextEditingController(text: '0.00');
  final _partnerPriceController = TextEditingController(text: '0.00');
  final _otherPriceController = TextEditingController(text: '0.00');
  final _memberSpecialRequirementsController = TextEditingController();
  final _partnerSpecialRequirementsController = TextEditingController();
  final _otherSpecialRequirementsController = TextEditingController();

  List<Map<String, dynamic>> _adminSummary = [];
  List<Map<String, dynamic>> _myReservations = [];
  String? _configEventId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final isAdmin = await UserService.isAdmin();
    final config = await RunnersBanquetService.getConfig(
      eventId: widget.eventId,
    );
    String? effectiveEventId = widget.eventId;

    // If opened from the menu (no eventId passed in), but the
    // latest config we loaded is tied to a specific event, use
    // that event id so that counts and settings stay in sync.
    if (effectiveEventId == null && config != null) {
      final dynamic eventIdValue = config['event_id'];
      if (eventIdValue is String && eventIdValue.isNotEmpty) {
        effectiveEventId = eventIdValue;
      }
    }

    List<Map<String, dynamic>> summary = [];
    List<Map<String, dynamic>> my = [];
    if (isAdmin) {
      // For now, show all banquet bookings regardless of event id so
      // admins can always see activity even if event ids don't line up.
      summary = await RunnersBanquetService.getAdminSummary();
    }

    // Load current user's bookings so we can show a confirmation box.
    // We do not restrict by event id here so that bookings are visible
    // even if the stored event id differs from the one passed in.
    my = await RunnersBanquetService.getMyReservations();

    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _configEventId = effectiveEventId;
      if (config != null) {
        final o1 = config['option1_label'] as String?;
        final o2 = config['option2_label'] as String?;
        final o3 = config['option3_label'] as String?;
        if (o1 != null && o1.isNotEmpty) _optionLabels[0].text = o1;
        if (o2 != null && o2.isNotEmpty && _optionLabels.length > 1) {
          _optionLabels[1].text = o2;
        }
        if (o3 != null && o3.isNotEmpty && _optionLabels.length > 2) {
          _optionLabels[2].text = o3;
        }
        final memberPence =
            (config['ticket_price_member_pence'] as int?) ??
            (config['ticket_price_pence'] as int?) ??
            0;
        final partnerPence =
            (config['ticket_price_partner_pence'] as int?) ?? memberPence;
        final otherPence =
            (config['ticket_price_other_pence'] as int?) ?? memberPence;

        _memberPriceController.text = (memberPence / 100.0).toStringAsFixed(2);
        _partnerPriceController.text = (partnerPence / 100.0).toStringAsFixed(
          2,
        );
        _otherPriceController.text = (otherPence / 100.0).toStringAsFixed(2);
      }
      _adminSummary = summary;
      _myReservations = my;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _memberPriceController.dispose();
    _partnerPriceController.dispose();
    _otherPriceController.dispose();
    _memberSpecialRequirementsController.dispose();
    _partnerSpecialRequirementsController.dispose();
    _otherSpecialRequirementsController.dispose();
    for (final c in _optionLabels) {
      c.dispose();
    }
    super.dispose();
  }

  num _parsePrice(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return 0;
    return num.tryParse(cleaned) ?? 0;
  }

  int get _memberPriceCents =>
      (_parsePrice(_memberPriceController.text) * 100).round();
  int get _partnerPriceCents =>
      (_parsePrice(_partnerPriceController.text) * 100).round();
  int get _otherPriceCents =>
      (_parsePrice(_otherPriceController.text) * 100).round();

  int get _totalQuantity => _memberQuantity + _partnerQuantity + _otherQuantity;

  int get _totalAmountCents =>
      _memberQuantity * _memberPriceCents +
      _partnerQuantity * _partnerPriceCents +
      _otherQuantity * _otherPriceCents;

  String _optionLabelForIndex(int index) {
    if (index < 0 || index >= _optionLabels.length) return 'Option';
    final text = _optionLabels[index].text.trim();
    if (text.isEmpty) return 'Option ${index + 1}';
    return text;
  }

  Future<void> _handleBuyPass() async {
    if (_totalAmountCents <= 0 || _totalQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter ticket prices and quantities.'),
        ),
      );
      return;
    }
    // Fallback to first option if none explicitly chosen
    final defaultIndex = _selectedOptionIndex >= 0 ? _selectedOptionIndex : 0;

    int _resolveIndex(int configuredIndex) {
      if (configuredIndex >= 0 && configuredIndex < _optionLabels.length) {
        return configuredIndex;
      }
      return defaultIndex;
    }

    final memberIndex = _memberQuantity > 0
        ? _resolveIndex(_selectedOptionIndex)
        : null;
    final partnerIndex = _partnerQuantity > 0
        ? _resolveIndex(_partnerOptionIndex)
        : null;
    final otherIndex = _otherQuantity > 0
        ? _resolveIndex(_otherOptionIndex)
        : null;

    final metadata = <String, dynamic>{
      'context': 'runners_banquet',
      'party_name': widget.eventTitle,
      'member_meal_option': memberIndex != null
          ? _optionLabelForIndex(memberIndex)
          : null,
      'partner_meal_option': partnerIndex != null
          ? _optionLabelForIndex(partnerIndex)
          : null,
      'other_meal_option': otherIndex != null
          ? _optionLabelForIndex(otherIndex)
          : null,
      'member_quantity': _memberQuantity,
      'partner_quantity': _partnerQuantity,
      'other_quantity': _otherQuantity,
      'total_quantity': _totalQuantity,
      'member_special_requirements': _memberSpecialRequirementsController.text
          .trim(),
      'partner_special_requirements': _partnerSpecialRequirementsController.text
          .trim(),
      'other_special_requirements': _otherSpecialRequirementsController.text
          .trim(),
    };

    final paid = await PaymentService.startMembershipPayment(
      context: context,
      tierName: (widget.eventTitle == null || widget.eventTitle!.isEmpty)
          ? 'Runners Banquet Pass'
          : widget.eventTitle!,
      amountCents: _totalAmountCents,
      metadata: metadata,
    );

    if (!paid || !mounted) return;

    final effectiveEventId = _configEventId ?? widget.eventId;

    // Clear any existing reservations for this user for this banquet
    // so that a new purchase replaces their previous choices.
    await RunnersBanquetService.clearMyReservationsForEvent(
      eventId: effectiveEventId,
    );

    // Record reservation rows per ticket type so admins see
    // counts per meal option.
    final eventId = effectiveEventId;

    String? _cleanSpecial(String text) {
      final trimmed = text.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    bool ok = true;
    if (memberIndex != null && _memberQuantity > 0) {
      ok = await RunnersBanquetService.addReservation(
        eventId: eventId,
        optionLabel: _optionLabelForIndex(memberIndex),
        quantity: _memberQuantity,
        specialRequirements: _cleanSpecial(
          _memberSpecialRequirementsController.text,
        ),
      );
    }
    if (ok && partnerIndex != null && _partnerQuantity > 0) {
      ok = await RunnersBanquetService.addReservation(
        eventId: eventId,
        optionLabel: _optionLabelForIndex(partnerIndex),
        quantity: _partnerQuantity,
        specialRequirements: _cleanSpecial(
          _partnerSpecialRequirementsController.text,
        ),
      );
    }
    if (ok && otherIndex != null && _otherQuantity > 0) {
      ok = await RunnersBanquetService.addReservation(
        eventId: eventId,
        optionLabel: _optionLabelForIndex(otherIndex),
        quantity: _otherQuantity,
        specialRequirements: _cleanSpecial(
          _otherSpecialRequirementsController.text,
        ),
      );
    }

    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment completed, but we could not save your banquet booking.',
          ),
        ),
      );
      return;
    }

    // Refresh admin summary so counts update immediately.
    // We do not filter by event so admins see all banquet bookings.
    if (_isAdmin) {
      final summary = await RunnersBanquetService.getAdminSummary();
      if (mounted) {
        setState(() {
          _adminSummary = summary;
        });
      }
    }

    // Refresh the current user's booking summary (confirmation box).
    final my = await RunnersBanquetService.getMyReservations();
    if (mounted) {
      setState(() {
        _myReservations = my;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment completed – thank you!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        ),
      );
    }

    final themeYellow = const Color(0xFFFFD700);
    final themeBlue = const Color(0xFF0057B7);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Runners Banquette',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeYellow.withOpacity(0.9), themeBlue],
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Party Pass & Food Orders',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              _showAdminQuickSummary(themeYellow);
                            },
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.black87,
                              size: 20,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set up your club banquet, share menus and let members book their passes and meal choices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_isAdmin) ...[
                _buildAdminSection(themeYellow, themeBlue),
                const SizedBox(height: 24),
              ] else ...[
                _buildOptionsSection(themeYellow, themeBlue),
                const SizedBox(height: 24),
              ],
              _buildPurchaseSection(themeYellow, themeBlue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAdminSection(Color themeYellow, Color themeBlue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Banquet Options (Admin Only)'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeBlue.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(_optionLabels.length, (index) {
                final optionNumber = index + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Option $optionNumber',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: themeYellow,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _optionLabels[index],
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color(0xFF161B26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Menu Pricing (Admin Only)'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeBlue.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Member Ticket Price (£)',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF161B26),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _partnerPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Partner/Spouse Ticket Price (£)',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF161B26),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _otherPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Other Guest Ticket Price (£)',
                        labelStyle: TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Color(0xFF161B26),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await RunnersBanquetService.saveConfig(
                      eventId: _configEventId ?? widget.eventId,
                      menuText: '',
                      optionLabels: _optionLabels
                          .map((c) => c.text.trim())
                          .toList(),
                      memberPricePence: _memberPriceCents,
                      partnerPricePence: _partnerPriceCents,
                      otherPricePence: _otherPriceCents,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Banquet settings saved.'
                              : 'Unable to save banquet settings.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'These prices apply to all new banquet bookings.',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection(Color themeYellow, Color themeBlue) {
    final optionIndices = List<int>.generate(
      _optionLabels.length,
      (i) => i,
    ).where((i) => _optionLabels[i].text.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Banquet Options'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeBlue.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              if (optionIndices.isEmpty)
                const Text(
                  'No options set yet – please check back later.',
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                )
              else
                ...optionIndices.map((index) {
                  final label = _optionLabels[index].text.trim();
                  final titleText = label.isEmpty
                      ? 'Option ${index + 1}'
                      : label.split('\n').first;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Option ${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: themeYellow,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B26),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeBlue.withOpacity(0.6),
                            ),
                          ),
                          child: Text(
                            label.isEmpty ? titleText : label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseSection(Color themeYellow, Color themeBlue) {
    final totalPounds = _totalAmountCents / 100.0;

    // For non-admins, once a booking exists we only show their
    // confirmation card and no longer allow another purchase.
    if (_myReservations.isNotEmpty && !_isAdmin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Your Banquet Booking'),
          _buildMyBookingSection(themeYellow),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Purchase Party Pass'),
        if (_myReservations.isNotEmpty && _isAdmin) ...[
          _buildMyBookingSection(themeYellow),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.04), Colors.white10],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Member Pass',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_memberQuantity > 0) _memberQuantity--;
                          });
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '$_memberQuantity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _memberQuantity++;
                          });
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_memberQuantity > 0) ...[
                _buildMealChoiceRow(
                  label: 'Member Meal Option',
                  currentIndex: _selectedOptionIndex,
                  onChanged: (i) {
                    setState(() {
                      _selectedOptionIndex = i;
                    });
                  },
                  themeYellow: themeYellow,
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _memberSpecialRequirementsController,
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Member Special Requirements',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF161B26),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Partner/Spouse Pass',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_partnerQuantity > 0) _partnerQuantity--;
                          });
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '$_partnerQuantity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _partnerQuantity++;
                          });
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_partnerQuantity > 0) ...[
                _buildMealChoiceRow(
                  label: 'Partner/Spouse Meal Option',
                  currentIndex: _partnerOptionIndex,
                  onChanged: (i) {
                    setState(() {
                      _partnerOptionIndex = i;
                    });
                  },
                  themeYellow: themeYellow,
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _partnerSpecialRequirementsController,
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Partner/Spouse Special Requirements',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF161B26),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Other Guest Pass',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_otherQuantity > 0) _otherQuantity--;
                          });
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '$_otherQuantity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _otherQuantity++;
                          });
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_otherQuantity > 0) ...[
                _buildMealChoiceRow(
                  label: 'Other Guest Meal Option',
                  currentIndex: _otherOptionIndex,
                  onChanged: (i) {
                    setState(() {
                      _otherOptionIndex = i;
                    });
                  },
                  themeYellow: themeYellow,
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _otherSpecialRequirementsController,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () => FocusScope.of(context).unfocus(),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Other Guest Special Requirements',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF161B26),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Passes',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    '$_totalQuantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total To Pay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '£${totalPounds.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: themeYellow,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleBuyPass,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text(
                    'Purchase Pass',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: themeBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Payments are handled securely via Stripe, the same as your membership.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealChoiceRow({
    required String label,
    required int currentIndex,
    required ValueChanged<int> onChanged,
    required Color themeYellow,
  }) {
    final optionIndices = List<int>.generate(
      _optionLabels.length,
      (i) => i,
    ).where((i) => _optionLabels[i].text.trim().isNotEmpty).toList();
    if (optionIndices.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              color: themeYellow,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: optionIndices.map((i) {
              final optionLabel = 'Option ${i + 1}';
              final isSelected = currentIndex == i;
              return ChoiceChip(
                label: Text(
                  optionLabel,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                selectedColor: themeYellow,
                backgroundColor: const Color(0xFF161B26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? themeYellow
                        : Colors.white.withOpacity(0.3),
                    width: 1.2,
                  ),
                ),
                onSelected: (_) => onChanged(i),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAdminQuickSummary(Color themeYellow) {
    if (!_isAdmin) return;

    // Group rows by option label.
    final Map<String, List<Map<String, dynamic>>> byOption = {};
    for (final row in _adminSummary) {
      final option = (row['option_label'] as String?) ?? 'Unknown';
      byOption.putIfAbsent(option, () => []).add(row);
    }

    final total = _adminSummary.fold<int>(
      0,
      (sum, r) => sum + (r['quantity'] as int? ?? 0),
    );

    final buffer = StringBuffer();
    byOption.forEach((option, rows) {
      final totalQty = rows.fold<int>(
        0,
        (sum, r) => sum + (r['quantity'] as int? ?? 0),
      );
      buffer.writeln('$option – $totalQty passes');
      for (final r in rows) {
        final profile = r['user_profiles'] as Map<String, dynamic>?;
        final name = (profile?['full_name'] as String?) ?? 'Unknown member';
        final qty = r['quantity'] as int? ?? 0;
        final special = (r['special_requirements'] as String?)?.trim();
        if (special != null && special.isNotEmpty) {
          buffer.writeln('  • $name x$qty – SPECIAL: $special');
        } else {
          buffer.writeln('  • $name x$qty');
        }
      }
      buffer.writeln();
    });

    final summaryText = buffer.toString().trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Banquet bookings (admin)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (total > 0)
                      Text(
                        '$total passes',
                        style: TextStyle(
                          color: themeYellow,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_adminSummary.isEmpty)
                  const Text(
                    'No bookings yet for this banquet.',
                    style: TextStyle(color: Colors.white70),
                  )
                else ...[
                  ...byOption.entries.map((entry) {
                    final option = entry.key;
                    final rows = entry.value;
                    final totalQty = rows.fold<int>(
                      0,
                      (sum, r) => sum + (r['quantity'] as int? ?? 0),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$option – $totalQty booked',
                            style: TextStyle(
                              color: themeYellow,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...rows.map((r) {
                            final profile =
                                r['user_profiles'] as Map<String, dynamic>?;
                            final name =
                                (profile?['full_name'] as String?) ??
                                'Unknown member';
                            final qty = r['quantity'] as int? ?? 0;
                            final special =
                                (r['special_requirements'] as String?)?.trim();
                            final baseText = '• $name x$qty';
                            final text = (special != null && special.isNotEmpty)
                                ? '$baseText – SPECIAL: $special'
                                : baseText;
                            return Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: summaryText),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Summary copied for export.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, color: Colors.white70),
                      label: const Text(
                        'Copy summary',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyBookingSection(Color themeYellow) {
    // Aggregate this user's reservations by option label.
    final Map<String, int> countsByOption = {};
    for (final row in _myReservations) {
      final option = (row['option_label'] as String?) ?? 'Unknown option';
      final qty = row['quantity'] as int? ?? 0;
      countsByOption.update(option, (v) => v + qty, ifAbsent: () => qty);
    }

    if (countsByOption.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = countsByOption.values.fold<int>(0, (s, v) => s + v);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your booking',
            style: TextStyle(color: themeYellow, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'You currently have $total pass${total == 1 ? '' : 'es'} booked for this banquet.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          ...countsByOption.entries.map(
            (e) => Text(
              '• ${e.value} × ${e.key}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your booking is now confirmed and can’t be changed here. If you need to amend numbers or meal choices, please contact the admin or message the event host.',
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }
}
