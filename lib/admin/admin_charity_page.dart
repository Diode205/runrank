import 'package:flutter/material.dart';
import 'package:runrank/services/charity_service.dart';

class AdminCharityEditorPage extends StatefulWidget {
  const AdminCharityEditorPage({super.key});

  @override
  State<AdminCharityEditorPage> createState() => _AdminCharityEditorPageState();
}

class _AdminCharityEditorPageState extends State<AdminCharityEditorPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _total = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await CharityService.getCharity();

    if (data != null) {
      _name.text = data['charity_name'] ?? '';
      _url.text = data['donate_url'] ?? '';
      _total.text = data['total_raised']?.toString() ?? '0';
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await CharityService.updateTotalRaised(double.tryParse(_total.text) ?? 0);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Charity updated")));
  }

  Future<void> _resetForNextSeason() async {
    await CharityService.setupCharity(name: _name.text, donateUrl: _url.text);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("New charity season started")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Charity")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: "Charity Name",
                      ),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    TextFormField(
                      controller: _url,
                      decoration: const InputDecoration(
                        labelText: "Donation URL",
                      ),
                    ),
                    TextFormField(
                      controller: _total,
                      decoration: const InputDecoration(
                        labelText: "Total Raised (£)",
                      ),
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _save,
                      child: const Text("Save Changes"),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _resetForNextSeason,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text("Reset for New Season"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
