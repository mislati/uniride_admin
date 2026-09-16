import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardModule extends StatelessWidget {
  const DashboardModule({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const Text('Real-time statistics and quick actions for the Uniride platform.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          
          // --- TOP ROW STAT CARDS ---
          Row(
            children: [
              _buildStatCard(
                context: context,
                title: 'Total Riders (All)',
                icon: Icons.person,
                color: const Color(0xFF5A5BFF),
                // FIX: Exclude the admin from the total count!
                query: FirebaseFirestore.instance.collection('users').where('role', isNotEqualTo: 'admin'), 
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                context: context,
                title: 'Total Drivers',
                icon: Icons.drive_eta,
                color: Colors.green,
                query: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'driver'),
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                context: context,
                title: 'Completed Rides',
                icon: Icons.check_circle,
                color: Colors.blueAccent,
                query: FirebaseFirestore.instance.collection('ride_requests').where('status', isEqualTo: 'completed'),
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // --- BOTTOM ROW ACTIONABLE STAT CARDS ---
          Row(
            children: [
              _buildStatCard(
                context: context,
                title: 'Active / Online Users',
                icon: Icons.wifi,
                color: Colors.teal,
                query: FirebaseFirestore.instance.collection('users').where('isOnline', isEqualTo: true),
                onTap: () => _showOnlineUsersDialog(context),
                tooltip: 'Click to view currently online users',
              ),
              const SizedBox(width: 24),
              _buildStatCard(
                context: context,
                title: 'Suspended Users',
                icon: Icons.block,
                color: Colors.redAccent,
                query: FirebaseFirestore.instance.collection('users').where('isSuspended', isEqualTo: true),
                onTap: () => _showSuspendedUsersDialog(context),
                tooltip: 'Click to view and unsuspend users',
              ),
              const Expanded(child: SizedBox()), 
            ],
          ),
        ],
      ),
    );
  }

  // --- STAT CARD BUILDER ---
  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Query query,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)],
        border: onTap != null ? Border.all(color: color.withAlpha(50), width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              if (onTap != null) Icon(Icons.open_in_new, color: Colors.grey[400], size: 18)
              else const Icon(Icons.show_chart, color: Colors.green),
            ],
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 33, width: 33, child: CircularProgressIndicator(strokeWidth: 2));
              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Text('$count', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
            },
          ),
        ],
      ),
    );

    return Expanded(
      child: tooltip != null
          ? Tooltip(
              message: tooltip,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(15),
                child: cardContent,
              ),
            )
          : cardContent,
    );
  }

  // --- DIALOG: VIEW ONLINE USERS ---
  void _showOnlineUsersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 600,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wifi, color: Colors.teal, size: 28),
                    SizedBox(width: 10),
                    Text('Currently Online Users', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 30),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('isOnline', isEqualTo: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      
                      // Also ensure the admin doesn't show up in the online list!
                      var onlineDocs = snapshot.data!.docs.where((doc) => (doc.data() as Map<String, dynamic>)['role'] != 'admin').toList();
                      
                      if (onlineDocs.isEmpty) return const Center(child: Text('No users are currently online.', style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        itemCount: onlineDocs.length,
                        itemBuilder: (context, index) {
                          var doc = onlineDocs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          String role = data['role'] ?? 'rider';
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: role == 'driver' ? Colors.green.withAlpha(26) : const Color(0xFF5A5BFF).withAlpha(26),
                              child: Icon(role == 'driver' ? Icons.drive_eta : Icons.person, color: role == 'driver' ? Colors.green : const Color(0xFF5A5BFF)),
                            ),
                            title: Text(data['fullName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${data['matricNumber']} • ${data['phone']}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.teal.withAlpha(26), borderRadius: BorderRadius.circular(10)),
                              child: const Text('ONLINE', style: TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black),
                    child: const Text('Close'),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- DIALOG: VIEW & MANAGE SUSPENDED USERS ---
  void _showSuspendedUsersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 600,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.block, color: Colors.redAccent, size: 28),
                    SizedBox(width: 10),
                    Text('Suspended Users', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 30),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('isSuspended', isEqualTo: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('There are no suspended users.', style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x33FF5252),
                              child: Icon(Icons.person_off, color: Colors.redAccent),
                            ),
                            title: Text(data['fullName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${data['matricNumber']} • ${(data['role'] ?? '').toUpperCase()}'),
                            trailing: ElevatedButton.icon(
                              onPressed: () {
                                FirebaseFirestore.instance.collection('users').doc(doc.id).update({'isSuspended': false});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('User unsuspended successfully.'), backgroundColor: Colors.green),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.lock_open, size: 16),
                              label: const Text('Unsuspend'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black),
                    child: const Text('Close'),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}