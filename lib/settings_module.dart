import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsModule extends StatefulWidget {
  const SettingsModule({super.key});

  @override
  State<SettingsModule> createState() => _SettingsModuleState();
}

class _SettingsModuleState extends State<SettingsModule> {
  final TextEditingController _baseFareController = TextEditingController();
  final TextEditingController _adminCutController = TextEditingController();
  final TextEditingController _supportEmailController = TextEditingController();
  final TextEditingController _supportPhoneController = TextEditingController();
  
  bool _isMaintenanceMode = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // --- FETCH SETTINGS FROM FIRESTORE ---
  Future<void> _loadSettings() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('settings').doc('platform').get();
      
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        _baseFareController.text = (data['baseFare'] ?? 200).toString();
        _adminCutController.text = (data['adminCutPercentage'] ?? 15).toString();
        _supportEmailController.text = data['supportEmail'] ?? '';
        _supportPhoneController.text = data['supportPhone'] ?? '';
        _isMaintenanceMode = data['isMaintenanceMode'] ?? false;
      } else {
        // Defaults if document doesn't exist yet
        _baseFareController.text = '200';
        _adminCutController.text = '15';
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SAVE SETTINGS TO FIRESTORE ---
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('settings').doc('platform').set({
        'baseFare': double.tryParse(_baseFareController.text.trim()) ?? 200,
        'adminCutPercentage': double.tryParse(_adminCutController.text.trim()) ?? 15,
        'supportEmail': _supportEmailController.text.trim(),
        'supportPhone': _supportPhoneController.text.trim(),
        'isMaintenanceMode': _isMaintenanceMode,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, width: 400),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating, width: 400),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _baseFareController.dispose();
    _adminCutController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF)));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Platform Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text('Manage pricing, campus operational status, and support details.', style: TextStyle(color: Colors.grey)),
                ],
              ),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A5BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.save),
                  label: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
          const SizedBox(height: 30),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- LEFT COLUMN ---
              Expanded(
                child: Column(
                  children: [
                    _buildSettingsCard(
                      title: 'Financial Configuration',
                      icon: Icons.payments,
                      iconColor: Colors.green,
                      children: [
                        _buildInputField(
                          label: 'Standard Ride Fare (₦)', 
                          controller: _baseFareController, 
                          icon: Icons.money,
                          helperText: 'The flat rate charged for intra-campus rides.',
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Admin Commission Cut (%)', 
                          controller: _adminCutController, 
                          icon: Icons.pie_chart,
                          helperText: 'The percentage of the fare kept by the platform.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSettingsCard(
                      title: 'Support & Contact',
                      icon: Icons.headset_mic,
                      iconColor: Colors.blue,
                      children: [
                        _buildInputField(
                          label: 'Support Email Address', 
                          controller: _supportEmailController, 
                          icon: Icons.email,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          label: 'Support Phone Number', 
                          controller: _supportPhoneController, 
                          icon: Icons.phone,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 24),

              // --- RIGHT COLUMN ---
              Expanded(
                child: Column(
                  children: [
                    _buildSettingsCard(
                      title: 'Operational Status',
                      icon: Icons.security,
                      iconColor: Colors.redAccent,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isMaintenanceMode ? Colors.redAccent.withAlpha(26) : Colors.green.withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isMaintenanceMode ? Colors.redAccent.withAlpha(50) : Colors.green.withAlpha(50))
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Maintenance Mode (Kill Switch)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Disable new ride requests across the campus.', 
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Switch(
                                value: _isMaintenanceMode,
                                activeColor: Colors.redAccent,
                                onChanged: (value) {
                                  setState(() => _isMaintenanceMode = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Note: Enabling Maintenance Mode immediately stops riders from booking new rides. Use this during school holidays, curfews, or server downtime.',
                          style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSettingsCard({required String title, required IconData icon, required Color iconColor, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withAlpha(26), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputField({required String label, required TextEditingController controller, required IconData icon, String? helperText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFFF4F6FF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(helperText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]
      ],
    );
  }
}