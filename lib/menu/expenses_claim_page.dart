import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class ExpensesClaimPage extends StatefulWidget {
  const ExpensesClaimPage({super.key});

  @override
  State<ExpensesClaimPage> createState() => _ExpensesClaimPageState();
}

class _ClaimLine {
  final TextEditingController descriptionController;
  final TextEditingController amountController;

  _ClaimLine()
    : descriptionController = TextEditingController(),
      amountController = TextEditingController();
}

class _ExpensesClaimPageState extends State<ExpensesClaimPage> {
  static const double _currencyBoxWidth = 120; // fits £000.00 snugly
  static const String _expensesRecipientEmail = 'peterrehill49@gmail.com';

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _dateController = TextEditingController();
  final _eventDetailsController = TextEditingController();
  final _mileageMilesController = TextEditingController();
  final _mileageAmountController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _sortCodeController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _notesController = TextEditingController();

  final List<_ClaimLine> _claimLines = [];

  bool _newDetailsSinceLastClaim = false;

  final _imagePicker = ImagePicker();
  final List<XFile> _receiptImages = [];
  final List<PlatformFile> _receiptFiles = [];

  @override
  void initState() {
    super.initState();
    _claimLines.add(_ClaimLine());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _postcodeController.dispose();
    _dateController.dispose();
    _eventDetailsController.dispose();
    _mileageMilesController.dispose();
    _mileageAmountController.dispose();
    _totalAmountController.dispose();
    _sortCodeController.dispose();
    _accountNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  Future<void> _addReceiptPhoto() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _receiptImages.add(image);
        });
      }
    } catch (_) {
      // Ignore picker errors; user can try again
    }
  }

  Future<void> _addReceiptFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'heic'],
        withData: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _receiptFiles.addAll(
            result.files.where((f) => (f.path ?? '').isNotEmpty),
          );
        });
      }
    } catch (_) {
      // Ignore picker errors; user can try again
    }
  }

  double _updateTotals() {
    double total = 0;

    // Mileage part
    final milesRaw = _mileageMilesController.text.trim();
    if (milesRaw.isNotEmpty) {
      final miles = double.tryParse(milesRaw);
      if (miles != null) {
        final mileageAmount = miles * 0.45;
        _mileageAmountController.text = mileageAmount.toStringAsFixed(2);
        total += mileageAmount;
      } else {
        _mileageAmountController.text = '';
      }
    } else {
      _mileageAmountController.text = '';
    }

    // Other claims
    for (final line in _claimLines) {
      final raw = line.amountController.text.trim().replaceAll('£', '');
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value != null) {
        total += value;
      }
    }

    _totalAmountController.text = total == 0 ? '' : total.toStringAsFixed(2);
    return total;
  }

  void _recalculateTotal() {
    setState(_updateTotals);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final subject = 'Expenses claim - ${_nameController.text.trim()}';

    final milesRaw = _mileageMilesController.text.trim();

    // Collect non-empty claim lines (both description and amount provided).
    final nonEmptyLines = _claimLines.where((line) {
      final desc = line.descriptionController.text.trim();
      final amt = line.amountController.text.trim();
      return desc.isNotEmpty && amt.isNotEmpty;
    }).toList();

    if (milesRaw.isEmpty && nonEmptyLines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add mileage or at least one other claim.'),
        ),
      );
      return;
    }

    // Ensure totals and mileage amount fields are up to date.
    final total = _updateTotals();
    final totalString = total.toStringAsFixed(2);

    final bodyBuffer = StringBuffer()
      ..writeln('Expenses claim submitted via NNBR app')
      ..writeln()
      ..writeln('Name: ${_nameController.text.trim()}')
      ..writeln('Email: ${_emailController.text.trim()}')
      ..writeln('Address: ${_addressController.text.trim()}')
      ..writeln('Postcode: ${_postcodeController.text.trim()}')
      ..writeln('Date of expense: ${_dateController.text.trim()}')
      // Event details removed from UI per design
      ..writeln('Details of claim:')
      ..writeln(
        [
          if (milesRaw.isNotEmpty)
            '- Mileage: ${milesRaw} miles @ £0.45/mile = £${_mileageAmountController.text.trim()}',
          ...nonEmptyLines.map(
            (line) =>
                '- ${line.descriptionController.text.trim()} (£${line.amountController.text.trim()})',
          ),
        ].join('\n'),
      )
      ..writeln()
      ..writeln('Total amount claimed: £$totalString')
      ..writeln()
      ..writeln('Bank details for settlement (UK accounts only):')
      ..writeln('  Sort code: ${_sortCodeController.text.trim()}')
      ..writeln('  Account number: ${_accountNumberController.text.trim()}')
      ..writeln(
        '  New details since last claim: ${_newDetailsSinceLastClaim ? 'Yes' : 'No'}',
      )
      ..writeln()
      ..writeln('Receipts attached with this claim:')
      ..writeln(
        [
          ..._receiptImages.map((x) => '- Photo: ${x.name}'),
          ..._receiptFiles.map((f) => '- File: ${f.name}'),
        ].join('\n'),
      )
      ..writeln()
      ..writeln('Additional notes:')
      ..writeln(_notesController.text.trim());

    // Build attachment list from picked images and files.
    final List<String> attachmentPaths = [];
    for (final image in _receiptImages) {
      if (image.path.isNotEmpty) {
        attachmentPaths.add(image.path);
      }
    }
    for (final file in _receiptFiles) {
      final path = file.path;
      if (path != null && path.isNotEmpty) {
        attachmentPaths.add(path);
      }
    }

    // Try to open the user's mail app via a mailto: link.
    final mailOpened = await _openMailFallback(subject, bodyBuffer.toString());

    if (!mailOpened) {
      // Final fallback: open system share sheet with attachments and body.
      final List<XFile> shareFiles = [];
      for (final image in _receiptImages) {
        if (image.path.isNotEmpty) shareFiles.add(XFile(image.path));
      }
      for (final file in _receiptFiles) {
        final p = file.path;
        if (p != null && p.isNotEmpty) shareFiles.add(XFile(p));
      }
      await Share.shareXFiles(
        shareFiles,
        text: bodyBuffer.toString(),
        subject: subject,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opened share sheet to send your claim.')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening your mail app to send the claim.'),
        ),
      );
    }
  }

  Future<bool> _openMailFallback(String subject, String body) async {
    final encode = Uri.encodeComponent;
    final uri = Uri.parse(
      'mailto:$_expensesRecipientEmail?subject=${encode(subject)}&body=${encode(body)}',
    );

    if (await canLaunchUrl(uri)) {
      final launched = await launchUrl(uri);
      return launched;
    }
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No email app is available; using share sheet.'),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const themeYellow = Color(0xFFFFD700);
    const themeBlue = Color(0xFF0057B7);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Expenses Claim Form',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeYellow.withOpacity(0.9), themeBlue],
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Club Expenses Claim',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Guidelines for Making an Expense Claim',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Submission: claims should be submitted to the Treasurer no later than three weeks after the relative event or expense.\n\n'
                      'Claims are settled as quickly as possible, and payment is made electronically, so please provide your bank details on the claim form and advise if they have changed since your last claim.\n\n'
                      'Please write clearly and ensure that all information given is correct, especially your bank details, as no liability can be accepted for incorrect information.\n\n'
                      'Receipts (or scans if using email) should always accompany claims except where none are available, e.g. car travel.\n\n'
                      'Travel by Car: mileage rate is 45p per mile.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color(0xFF161B26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color(0xFF161B26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          labelStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color(0xFF161B26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _postcodeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Post Code',
                          labelStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color(0xFF161B26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Expenses Claim Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color.fromRGBO(246, 242, 39, 0.874),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Removed 'Expenses / Event Details' to keep details in 'Other Claims'
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Date Of Expenses',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _dateController,
                                    readOnly: true,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Color(0xFF161B26),
                                      suffixIcon: Icon(
                                        Icons.calendar_today,
                                        color: Colors.white70,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                    onTap: () async {
                                      final now = DateTime.now();
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: now,
                                        firstDate: DateTime(now.year - 2),
                                        lastDate: DateTime(now.year + 1),
                                      );
                                      if (picked != null) {
                                        _dateController.text =
                                            '${picked.day.toString().padLeft(2, '0')}/'
                                            '${picked.month.toString().padLeft(2, '0')}/'
                                            '${picked.year}';
                                      }
                                    },
                                    validator: _required,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Mileage Claim',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _mileageMilesController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      labelText: 'Miles',
                                      labelStyle: TextStyle(
                                        color: Colors.white70,
                                      ),
                                      suffixText: 'x  £0.45/mile',
                                      suffixStyle: TextStyle(
                                        color: Colors.white70,
                                      ),
                                      filled: true,
                                      fillColor: Color(0xFF161B26),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                    onChanged: (_) => _recalculateTotal(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: _currencyBoxWidth,
                                  child: TextFormField(
                                    controller: _mileageAmountController,
                                    readOnly: true,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      prefixText: '£',
                                      prefixStyle: TextStyle(
                                        color: Colors.white70,
                                      ),
                                      filled: true,
                                      fillColor: Color(0xFF161B26),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Other Claims',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ..._claimLines.asMap().entries.map((entry) {
                              final index = entry.key;
                              final line = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: line.descriptionController,
                                        maxLines: 2,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: const InputDecoration(
                                          hintText:
                                              'Describe expense (e.g. race entry, travel)',
                                          hintStyle: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                          filled: true,
                                          fillColor: Color(0xFF161B26),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(8),
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          final desc = value?.trim() ?? '';
                                          final amt = line.amountController.text
                                              .trim();
                                          if (desc.isEmpty && amt.isEmpty) {
                                            return null; // ignore empty row
                                          }
                                          if (desc.isEmpty || amt.isEmpty) {
                                            return 'Please fill both description and amount or leave blank';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: _currencyBoxWidth,
                                      child: TextFormField(
                                        controller: line.amountController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          prefixText: '£',
                                          prefixStyle: TextStyle(
                                            color: Colors.white70,
                                          ),
                                          filled: true,
                                          fillColor: Color(0xFF161B26),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(8),
                                            ),
                                          ),
                                        ),
                                        onChanged: (_) => _recalculateTotal(),
                                        validator: (value) {
                                          final amt = value?.trim() ?? '';
                                          final desc = line
                                              .descriptionController
                                              .text
                                              .trim();
                                          if (desc.isEmpty && amt.isEmpty) {
                                            return null; // ignore empty row
                                          }
                                          if (desc.isEmpty || amt.isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    if (_claimLines.length > 1)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _claimLines.removeAt(index);
                                          });
                                          _recalculateTotal();
                                        },
                                      ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _claimLines.add(_ClaimLine());
                                  });
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add another item'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total Amount To Claim',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: _currencyBoxWidth,
                                  child: TextFormField(
                                    controller: _totalAmountController,
                                    readOnly: true,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      prefixText: '£',
                                      prefixStyle: TextStyle(
                                        color: Colors.white70,
                                      ),
                                      filled: true,
                                      fillColor: Color(0xFF161B26),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Bank Details (UK Accounts Only)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _sortCodeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Sort Code',
                          labelStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color(0xFF161B26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _accountNumberController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Account Number',
                          labelStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color(0xFF161B26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Switch(
                            value: _newDetailsSinceLastClaim,
                            activeColor: themeYellow,
                            onChanged: (value) {
                              setState(() {
                                _newDetailsSinceLastClaim = value;
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'New bank details since last claim?',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Receipts And Supporting Documents',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addReceiptPhoto,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Add Receipt'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color.fromRGBO(242, 235, 22, 0.964),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addReceiptFile,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('PDF/Image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color.fromRGBO(246, 242, 39, 0.874),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_receiptImages.isNotEmpty ||
                          _receiptFiles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Selected receipts (please attach these in your email):',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        ...[
                          ..._receiptImages.map((x) => x.name),
                          ..._receiptFiles.map((f) => f.name),
                        ].map(
                          (name) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• $name',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Add Optional Notes',
                          labelStyle: TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Color(0xFF161B26),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          icon: const Icon(Icons.send),
                          label: const Text('Submit Claim Via Email'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your email app will open with the claim details and selected receipts attached. Please review before sending.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
