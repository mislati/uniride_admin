import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LiveRidesModule extends StatelessWidget {
  const LiveRidesModule({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Live Rides Tracker', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Text('Monitor active and pending ride requests across the campus in real-time.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 30),
        
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- LEFT COLUMN: PENDING RIDES ---
              Expanded(
                child: _buildRideColumn(
                  title: 'Pending Requests',
                  statusFilter: 'pending',
                  headerColor: const Color(0xFF5A5BFF),
                  icon: Icons.access_time_filled,
                  emptyMessage: 'No pending ride requests.',
                ),
              ),
              const SizedBox(width: 24),
              // --- RIGHT COLUMN: ACTIVE RIDES ---
              Expanded(
                child: _buildRideColumn(
                  title: 'Active Rides (En Route)',
                  statusFilter: 'accepted',
                  headerColor: Colors.orange,
                  icon: Icons.drive_eta,
                  emptyMessage: 'No active rides at the moment.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRideColumn({
    required String title,
    required String statusFilter,
    required Color headerColor,
    required IconData icon,
    required String emptyMessage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)],
      ),
      child: Column(
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: headerColor.withAlpha(26),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(icon, color: headerColor),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: headerColor)),
                const Spacer(),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('ride_requests').where('status', isEqualTo: statusFilter).snapshots(),
                  builder: (context, snapshot) {
                    int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: headerColor, borderRadius: BorderRadius.circular(20)),
                      child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    );
                  },
                )
              ],
            ),
          ),
          
          // Column List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ride_requests').where('status', isEqualTo: statusFilter).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 50, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(emptyMessage, style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                var rides = snapshot.data!.docs;
                // Sort newest first
                rides.sort((a, b) {
                  Timestamp? tA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  Timestamp? tB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  if (tA == null || tB == null) return 0;
                  return tB.compareTo(tA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    var rideDoc = rides[index];
                    return _RideCard(rideDoc: rideDoc, status: statusFilter);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- INDIVIDUAL RIDE CARD WIDGET ---
class _RideCard extends StatelessWidget {
  final QueryDocumentSnapshot rideDoc;
  final String status;

  const _RideCard({required this.rideDoc, required this.status});

  void _adminOverrideAction(BuildContext context, String newStatus, String successMessage) {
    FirebaseFirestore.instance.collection('ride_requests').doc(rideDoc.id).update({
      'status': newStatus,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: newStatus == 'completed' ? Colors.green : Colors.redAccent));
    });
  }

  @override
  Widget build(BuildContext context) {
    var data = rideDoc.data() as Map<String, dynamic>;
    Timestamp? ts = data['createdAt'] as Timestamp?;
    String timeRequested = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : 'Unknown Time';
    
    String riderId = data['riderId'] ?? '';
    String driverId = data['driverId'] ?? '';
    double price = (data['price'] ?? 200).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route and Price Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.route, color: Color(0xFF5A5BFF), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From: ${data['pickupLocation'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('To: ${data['destination'] ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₦${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                  Text(timeRequested, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )
            ],
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1),
          ),

          // User Resolvers (Fetching names based on IDs)
          _buildUserResolverRow('Rider', riderId, Icons.person, const Color(0xFF5A5BFF)),
          if (status == 'accepted' && driverId.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildUserResolverRow('Driver', driverId, Icons.drive_eta, Colors.orange),
          ],

          const SizedBox(height: 16),
          
          // Admin Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _adminOverrideAction(context, 'cancelled', 'Ride forcefully cancelled.'),
                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                label: const Text('Cancel Ride', style: TextStyle(color: Colors.redAccent)),
              ),
              if (status == 'accepted') ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _adminOverrideAction(context, 'completed', 'Ride marked as completed.'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: const Text('Mark Complete', style: TextStyle(color: Colors.white)),
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  // FutureBuilder to grab the User's Name and Matric Number on the fly without lagging the stream
  Widget _buildUserResolverRow(String label, String uid, IconData icon, Color color) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        String displayName = 'Loading...';
        String displayMatric = '';
        
        if (snapshot.hasData && snapshot.data!.exists) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          displayName = userData['fullName'] ?? 'Unknown User';
          displayMatric = userData['matricNumber'] ?? '';
        } else if (snapshot.hasError) {
          displayName = 'Error loading user';
        }

        return Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(
              child: Text('$displayName ${displayMatric.isNotEmpty ? '($displayMatric)' : ''}', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}