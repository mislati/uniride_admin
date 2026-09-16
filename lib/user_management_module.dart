import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserManagementModule extends StatelessWidget {
  final String role;
  final String title;
  final String subtitle;

  const UserManagementModule({
    super.key,
    required this.role,
    required this.title,
    required this.subtitle,
  });

  void _confirmDelete(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('Confirm Deletion'),
          ],
        ),
        content: Text('Are you sure you want to permanently delete $name? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              FirebaseFirestore.instance.collection('users').doc(uid).delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User deleted successfully.'), backgroundColor: Colors.redAccent),
              );
            },
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserSuspension(BuildContext context, String uid, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isSuspended': !currentStatus,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus ? 'User suspended successfully.' : 'User unsuspended.'),
            backgroundColor: !currentStatus ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.floating,
            width: 400,
          )
        );
      }
    } catch (e) {
      debugPrint("Error updating suspension status: $e");
    }
  }

  // NEW FIX: Dialog now securely fetches dynamic settings instead of hardcoding 15%!
  void _showUserProfileDialog(BuildContext context, String uid, Map<String, dynamic> userData) {
    String actualRole = userData['role'] ?? 'rider';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('settings').doc('platform').get(),
            builder: (context, snapshot) {
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 500, height: 300,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF))),
                );
              }

              double currentCut = 15.0;
              if (snapshot.hasData && snapshot.data!.exists) {
                var sData = snapshot.data!.data() as Map<String, dynamic>;
                currentCut = (sData['adminCutPercentage'] ?? 15.0).toDouble();
              }
              
              double adminFraction = currentCut / 100.0;
              double driverFraction = 1.0 - adminFraction;
              int displayCut = currentCut.toInt();
              int displayDriver = 100 - displayCut;

              double driverNet = (userData['earnings'] ?? 0).toDouble();
              double grossEarnings = driverFraction > 0 ? (driverNet / driverFraction) : 0;
              double adminCutAmount = grossEarnings * adminFraction;

              return Container(
                width: 500,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85), 
                padding: const EdgeInsets.all(32),
                child: SingleChildScrollView( 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF5A5BFF).withAlpha(26),
                        child: Icon(actualRole == 'driver' ? Icons.drive_eta : Icons.person, size: 50, color: const Color(0xFF5A5BFF)),
                      ),
                      const SizedBox(height: 16),
                      Text(userData['fullName'] ?? 'Unknown User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: actualRole == 'driver' ? Colors.green.withAlpha(26) : const Color(0xFF5A5BFF).withAlpha(26),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          actualRole.toUpperCase(), 
                          style: TextStyle(color: actualRole == 'driver' ? Colors.green : const Color(0xFF5A5BFF), fontWeight: FontWeight.bold, fontSize: 12)
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildProfileDetailRow(Icons.badge, 'Matric No.', userData['matricNumber'] ?? 'N/A'),
                      const SizedBox(height: 16),
                      _buildProfileDetailRow(Icons.email, 'Email', userData['email'] ?? 'N/A'),
                      const SizedBox(height: 16),
                      _buildProfileDetailRow(Icons.phone, 'Phone', userData['phone'] ?? 'N/A'),
                      
                      if (actualRole == 'driver') ...[
                        const SizedBox(height: 16),
                        _buildProfileDetailRow(Icons.motorcycle, 'Bike Brand', userData['bikeBrand'] ?? 'N/A'),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text('Earnings Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 16),
                        _buildProfileDetailRow(Icons.account_balance_wallet, 'Gross Generated', '₦${grossEarnings.toStringAsFixed(2)}'),
                        const SizedBox(height: 8),
                        _buildProfileDetailRow(Icons.payments, 'Driver Net ($displayDriver%)', '₦${driverNet.toStringAsFixed(2)}', valueColor: Colors.green),
                        const SizedBox(height: 8),
                        _buildProfileDetailRow(Icons.corporate_fare, 'Admin Cut ($displayCut%)', '₦${adminCutAmount.toStringAsFixed(2)}', valueColor: const Color(0xFF5A5BFF)),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      const Text('Recent Ride History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('ride_requests')
                            .where(actualRole == 'driver' ? 'driverId' : 'riderId', isEqualTo: uid)
                            .limit(5) 
                            .snapshots(),
                        builder: (context, rideSnapshot) {
                          if (rideSnapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          if (!rideSnapshot.hasData || rideSnapshot.data!.docs.isEmpty) {
                            return const Text('No rides found for this user.', style: TextStyle(color: Colors.grey));
                          }

                          var rides = rideSnapshot.data!.docs;
                          return Column(
                            children: rides.map((rideDoc) {
                              var ride = rideDoc.data() as Map<String, dynamic>;
                              String status = ride['status'] ?? 'unknown';
                              Color statusColor = status == 'completed' ? Colors.green : (status == 'pending' ? const Color(0xFF5A5BFF) : Colors.orange);
                              double ridePrice = (ride['price'] ?? 200).toDouble();

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.location_on, color: statusColor),
                                title: Text(ride['destination'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('Status: ${status.toUpperCase()}', style: TextStyle(color: statusColor, fontSize: 12)),
                                trailing: Text('₦${ridePrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A5BFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: const Text('Close Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              );
            }
          ),
        );
      }
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String title, String value, {Color valueColor = Colors.black}) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 16)),
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
              stream: role == 'rider' 
                  ? FirebaseFirestore.instance.collection('users').snapshots()
                  : FirebaseFirestore.instance.collection('users').where('role', isEqualTo: role).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF)));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No users found in this category.', style: TextStyle(color: Colors.grey, fontSize: 16)));

                var docs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data['role'] != 'admin';
                }).toList();

                docs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  Timestamp? tA = dataA['createdAt'] as Timestamp?;
                  Timestamp? tB = dataB['createdAt'] as Timestamp?;
                  if (tA == null || tB == null) return 0;
                  return tB.compareTo(tA);
                });

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal, 
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: constraints.maxWidth), 
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.resolveWith((states) => const Color(0xFFF4F6FF)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            dataRowMaxHeight: 65,
                            columns: const [
                              DataColumn(label: Text('Full Name')),
                              DataColumn(label: Text('Matric No.')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Contact')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: docs.map((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              
                              String name = data['fullName'] ?? 'N/A';
                              String matric = data['matricNumber'] ?? 'N/A';
                              String phone = data['phone'] ?? 'N/A';
                              bool isOnline = data['isOnline'] ?? false;
                              bool isSuspended = data['isSuspended'] ?? false;
                              String actualRole = data['role'] ?? 'rider';

                              return DataRow(
                                cells: [
                                  DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(matric)),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: actualRole == 'driver' ? Colors.green.withAlpha(26) : const Color(0xFF5A5BFF).withAlpha(26),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        actualRole.toUpperCase(), 
                                        style: TextStyle(color: actualRole == 'driver' ? Colors.green : const Color(0xFF5A5BFF), fontWeight: FontWeight.bold, fontSize: 12)
                                      ),
                                    )
                                  ),
                                  DataCell(Text(phone)),
                                  DataCell(
                                    Row(
                                      children: [
                                        Icon(Icons.circle, size: 10, color: isOnline ? Colors.green : Colors.grey),
                                        const SizedBox(width: 8),
                                        Text(isOnline ? 'Online' : 'Offline', style: const TextStyle(color: Colors.grey)),
                                      ],
                                    )
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        Tooltip(
                                          message: 'View Profile & History',
                                          child: IconButton(
                                            icon: const Icon(Icons.visibility, color: Colors.blue),
                                            onPressed: () => _showUserProfileDialog(context, doc.id, data),
                                          ),
                                        ),
                                        Tooltip(
                                          message: isSuspended ? 'Unsuspend User' : 'Suspend User',
                                          child: IconButton(
                                            icon: Icon(isSuspended ? Icons.lock_open : Icons.block, color: isSuspended ? Colors.green : Colors.orange),
                                            onPressed: () => _toggleUserSuspension(context, doc.id, isSuspended),
                                          ),
                                        ),
                                        Tooltip(
                                          message: 'Delete User Data',
                                          child: IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                            onPressed: () => _confirmDelete(context, doc.id, name),
                                          ),
                                        ),
                                      ],
                                    )
                                  ),
                                ]
                              );
                            }).toList(),
                          ),
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