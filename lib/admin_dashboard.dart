import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_login_screen.dart';
import 'user_management_module.dart'; 
import 'dashboard_module.dart'; 
import 'reports_module.dart'; 
import 'live_rides_module.dart'; 
import 'settings_module.dart'; // <-- Imported the new settings module!

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final TextEditingController _matricController = TextEditingController();
  bool _isApproving = false;

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
      );
    }
  }

  Future<void> _approveDriver() async {
    String inputMatric = _matricController.text.trim().toUpperCase();
    if (inputMatric.isEmpty) {
      _showSnackbar('Please enter a Matric Number.', isError: true);
      return;
    }

    setState(() => _isApproving = true);

    try {
      String safeMatricId = inputMatric.replaceAll('/', '');

      await FirebaseFirestore.instance.collection('approved_drivers').doc(safeMatricId).set({
        'matricNumber': inputMatric, 
        'isRegistered': false, 
        'createdAt': FieldValue.serverTimestamp(),
        'driverUid': null, 
      });

      _matricController.clear();
      _showSnackbar('Matric Number $inputMatric has been authorized!');
    } catch (e) {
      _showSnackbar('Error authorizing driver: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _revokeApproval(String docId, String displayMatric) async {
    try {
      await FirebaseFirestore.instance.collection('approved_drivers').doc(docId).delete();
      _showSnackbar('Authorization revoked for $displayMatric.');
    } catch (e) {
      _showSnackbar('Error revoking authorization.', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        width: 400, 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FF),
      appBar: AppBar(
        title: const Text('Uniride Control Center', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
            ),
          )
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SIDEBAR NAVIGATION ---
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            selectedIconTheme: const IconThemeData(color: Color(0xFF5A5BFF)),
            selectedLabelTextStyle: const TextStyle(color: Color(0xFF5A5BFF), fontWeight: FontWeight.bold),
            unselectedIconTheme: const IconThemeData(color: Colors.grey),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.verified_user_outlined), selectedIcon: Icon(Icons.verified_user), label: Text('Approvals')),
              NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('Riders')),
              NavigationRailDestination(icon: Icon(Icons.drive_eta_outlined), selectedIcon: Icon(Icons.drive_eta), label: Text('Drivers')),
              NavigationRailDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: Text('Live Rides')),
              NavigationRailDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: Text('Reports')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          
          // --- MAIN CONTENT AREA ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardModule(); 
      case 1:
        return _buildDriverApprovalModule();
      case 2:
        return const UserManagementModule(role: 'rider', title: 'Rider Management', subtitle: 'Manage all registered student riders.');
      case 3:
        return const UserManagementModule(role: 'driver', title: 'Driver Management', subtitle: 'Manage all registered campus drivers.');
      case 4:
        return const LiveRidesModule(); 
      case 5:
        return const ReportsModule(); 
      case 6:
        return const SettingsModule(); // <-- Connected the new Settings module here!
      default:
        return const DashboardModule();
    }
  }

  // --- DRIVER APPROVAL MODULE ---
  Widget _buildDriverApprovalModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Driver Approvals', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Text('Authorize student matric numbers to allow them to register as drivers.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _matricController,
                  decoration: InputDecoration(
                    labelText: 'Enter Student Matric Number (e.g., UG22/SCCS/1153)',
                    prefixIcon: const Icon(Icons.badge, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF4F6FF),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _approveDriver(),
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isApproving ? null : _approveDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A5BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isApproving ? const SizedBox.shrink() : const Icon(Icons.add),
                  label: _isApproving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Authorize Driver', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
        
        const SizedBox(height: 30),

        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)],
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('approved_drivers').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF)));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No matric numbers have been authorized yet.", style: TextStyle(color: Colors.grey)));

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth), 
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFF4F6FF)),
                          columns: const [
                            DataColumn(label: Text('Matric Number', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: snapshot.data!.docs.map((doc) {
                            String docId = doc.id;
                            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                            String displayMatric = data.containsKey('matricNumber') ? data['matricNumber'] : docId;
                            bool isRegistered = data['isRegistered'] ?? false;

                            return DataRow(
                              cells: [
                                DataCell(Text(displayMatric, style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isRegistered ? Colors.green.withAlpha(26) : Colors.orange.withAlpha(26),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isRegistered ? 'Registered' : 'Pending Sign-up',
                                      style: TextStyle(color: isRegistered ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    tooltip: 'Revoke Authorization',
                                    onPressed: () => _revokeApproval(docId, displayMatric), 
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}