import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReportsModule extends StatefulWidget {
  const ReportsModule({super.key});

  @override
  State<ReportsModule> createState() => _ReportsModuleState();
}

class _ReportsModuleState extends State<ReportsModule> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimeframe = 'All Time';
  final List<String> _timeframes = ['Today', 'This Week', 'This Month', 'This Year', 'All Time'];

  String? _selectedDriverId;
  Map<String, dynamic>? _selectedDriverData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _downloadCSV(String csvData, String filename) {
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  bool _isDateInFilter(DateTime date) {
    DateTime now = DateTime.now();
    if (_selectedTimeframe == 'Today') {
      return date.year == now.year && date.month == now.month && date.day == now.day;
    } else if (_selectedTimeframe == 'This Week') {
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      return date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
    } else if (_selectedTimeframe == 'This Month') {
      return date.year == now.year && date.month == now.month;
    } else if (_selectedTimeframe == 'This Year') {
      return date.year == now.year;
    }
    return true; 
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reports & Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Text('Financial overviews, ride statistics, and CSV exports.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF5A5BFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF5A5BFF),
          onTap: (index) {
            setState(() {});
          },
          tabs: const [
            Tab(text: 'Cumulative Platform Analytics'),
            Tab(text: 'Individual Driver Analytics'),
          ],
        ),
        const SizedBox(height: 24),
        
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').doc('platform').snapshots(),
            builder: (context, settingsSnapshot) {
              if (settingsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF5A5BFF)));
              }

              double dynamicAdminCut = 15.0;
              if (settingsSnapshot.hasData && settingsSnapshot.data!.exists) {
                var data = settingsSnapshot.data!.data() as Map<String, dynamic>;
                dynamicAdminCut = (data['adminCutPercentage'] ?? 15.0).toDouble();
              }

              return IndexedStack(
                index: _tabController.index,
                children: [
                  _buildCumulativeAnalytics(dynamicAdminCut),
                  _buildIndividualDriverAnalytics(dynamicAdminCut),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCumulativeAnalytics(double adminCutPercentage) {
    double adminFraction = adminCutPercentage / 100.0;
    double driverFraction = 1.0 - adminFraction;
    int adminFlex = adminCutPercentage.round();
    int driverFlex = 100 - adminFlex;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ride_requests').where('status', isEqualTo: 'completed').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData) return const Center(child: Text('No data available.'));

        List<QueryDocumentSnapshot> allRides = snapshot.data!.docs;
        List<QueryDocumentSnapshot> filteredRides = [];
        
        double totalRevenue = 0;

        for (var doc in allRides) {
          var data = doc.data() as Map<String, dynamic>;
          Timestamp? timestamp = data['createdAt'] as Timestamp?;
          if (timestamp != null) {
            DateTime date = timestamp.toDate();
            if (_isDateInFilter(date)) {
              filteredRides.add(doc);
              totalRevenue += (data['price'] ?? 200).toDouble(); 
            }
          }
        }

        double adminProfit = totalRevenue * adminFraction;
        double driverEarnings = totalRevenue * driverFraction;
        int totalRides = filteredRides.length;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTimeframe,
                        items: _timeframes.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (newValue) => setState(() => _selectedTimeframe = newValue!),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      String csv = "Ride ID,Date,Driver ID,Rider ID,Pickup,Destination,Gross Price (NGN),Driver Net (NGN),Admin Cut (NGN)\n";
                      for (var ride in filteredRides) {
                        var data = ride.data() as Map<String, dynamic>;
                        Timestamp? ts = data['createdAt'] as Timestamp?;
                        String formattedDate = ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate()) : 'Unknown Date';
                        double price = (data['price'] ?? 200).toDouble();
                        
                        csv += "${ride.id},$formattedDate,${data['driverId']},${data['riderId']},\"${data['pickupLocation']}\",\"${data['destination']}\",$price,${price * driverFraction},${price * adminFraction}\n";
                      }
                      _downloadCSV(csv, "Uniride_Platform_Report_${_selectedTimeframe.replaceAll(' ', '_')}.csv");
                    },
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                  )
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  _buildKpiCard('Total Revenue', '₦${totalRevenue.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.blue),
                  const SizedBox(width: 16),
                  _buildKpiCard('Admin Profit ($adminFlex%)', '₦${adminProfit.toStringAsFixed(2)}', Icons.corporate_fare, const Color(0xFF5A5BFF)),
                  const SizedBox(width: 16),
                  _buildKpiCard('Driver Earnings ($driverFlex%)', '₦${driverEarnings.toStringAsFixed(2)}', Icons.payments, Colors.green),
                  const SizedBox(width: 16),
                  _buildKpiCard('Total Completed Rides', '$totalRides', Icons.check_circle, Colors.orange),
                ],
              ),
              const SizedBox(height: 32),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revenue Split Visualization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        children: [
                          if (driverFlex > 0)
                            Expanded(
                              flex: driverFlex,
                              child: Container(
                                height: 40, color: Colors.green,
                                child: Center(child: Text('Driver Net ($driverFlex%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              ),
                            ),
                          if (adminFlex > 0)
                            Expanded(
                              flex: adminFlex,
                              child: Container(
                                height: 40, color: const Color(0xFF5A5BFF),
                                child: Center(child: Text('Admin ($adminFlex%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildKpiCard(String title, String amount, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 4),
            Text(amount, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualDriverAnalytics(double adminCutPercentage) {
    double adminFraction = adminCutPercentage / 100.0;
    double driverFraction = 1.0 - adminFraction;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'driver').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView.separated(
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isSelected = _selectedDriverId == doc.id;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: const Color(0xFF5A5BFF).withAlpha(26),
                      leading: const CircleAvatar(backgroundColor: Color(0xFFF4F6FF), child: Icon(Icons.drive_eta, color: Color(0xFF5A5BFF))),
                      title: Text(data['fullName'] ?? 'Unknown', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(data['matricNumber'] ?? ''),
                      onTap: () {
                        setState(() {
                          _selectedDriverId = doc.id;
                          _selectedDriverData = data;
                        });
                      },
                    );
                  },
                );
              }
            ),
          ),
        ),
        const SizedBox(width: 24),
        
        Expanded(
          flex: 2,
          child: _selectedDriverId == null 
            ? const Center(child: Text('Select a driver from the list to view their analytics.', style: TextStyle(color: Colors.grey, fontSize: 16)))
            : _buildDriverDetailView(adminFraction, driverFraction),
        ),
      ],
    );
  }

  Widget _buildDriverDetailView(double adminFraction, double driverFraction) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ride_requests')
          .where('driverId', isEqualTo: _selectedDriverId)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        List<QueryDocumentSnapshot> driverRides = snapshot.data!.docs;
        
        driverRides.sort((a, b) {
          Timestamp? tA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          Timestamp? tB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        // NEW FIX: Dynamic Current Week Calculation added!
        double grossGenerated = 0;
        double thisWeekGross = 0;
        
        DateTime now = DateTime.now();
        DateTime startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

        for (var ride in driverRides) {
          double price = ((ride.data() as Map<String, dynamic>)['price'] ?? 200).toDouble();
          grossGenerated += price;
          
          Timestamp? ts = (ride.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (ts != null && ts.toDate().millisecondsSinceEpoch >= startOfWeek.millisecondsSinceEpoch) {
            thisWeekGross += price;
          }
        }
        
        double netEarnings = grossGenerated * driverFraction;
        double adminCutAmount = grossGenerated * adminFraction;
        double weeklyAdminDue = thisWeekGross * adminFraction; 

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_selectedDriverData?['fullName']} Analytics', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('${_selectedDriverData?['matricNumber']} | Total Rides: ${driverRides.length}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        String csv = "Date,Pickup,Destination,Gross (NGN),Driver Net (NGN),Admin Cut (NGN)\n";
                        for (var ride in driverRides) {
                          var data = ride.data() as Map<String, dynamic>;
                          Timestamp? ts = data['createdAt'] as Timestamp?;
                          String formattedDate = ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate()) : 'Unknown Date';
                          double price = (data['price'] ?? 200).toDouble();
                          csv += "$formattedDate,\"${data['pickupLocation']}\",\"${data['destination']}\",$price,${price * driverFraction},${price * adminFraction}\n";
                        }
                        _downloadCSV(csv, "${_selectedDriverData?['matricNumber']}_Ride_History.csv");
                      },
                      icon: const Icon(Icons.download, color: Colors.white, size: 18),
                      label: const Text('Export Driver Data', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5A5BFF)),
                    )
                  ],
                ),
                const Divider(height: 40),
                
                Row(
                  children: [
                    _buildKpiCard('Gross Generated', '₦${grossGenerated.toStringAsFixed(2)}', Icons.monetization_on, Colors.blueGrey),
                    const SizedBox(width: 16),
                    _buildKpiCard('Driver Net', '₦${netEarnings.toStringAsFixed(2)}', Icons.payments, Colors.green),
                    const SizedBox(width: 16),
                    _buildKpiCard('Total Admin Cut', '₦${adminCutAmount.toStringAsFixed(2)}', Icons.corporate_fare, const Color(0xFF5A5BFF)),
                    const SizedBox(width: 16),
                    _buildKpiCard('Weekly Admin Due', '₦${weeklyAdminDue.toStringAsFixed(2)}', Icons.warning_amber_rounded, Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 30),
                
                const Text('Complete Ride History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                driverRides.isEmpty 
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No completed rides yet.', style: TextStyle(color: Colors.grey))),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: driverRides.length,
                      itemBuilder: (context, index) {
                        var rideData = driverRides[index].data() as Map<String, dynamic>;
                        Timestamp? ts = rideData['createdAt'] as Timestamp?;
                        String displayDate = ts != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(ts.toDate()) : 'Unknown Date';
                        double price = (rideData['price'] ?? 200).toDouble();
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(backgroundColor: Color(0xFFF4F6FF), child: Icon(Icons.location_on, color: Colors.green)),
                          title: Text(rideData['destination'] ?? 'Unknown Destination', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$displayDate | From: ${rideData['pickupLocation']}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Gross: ₦${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Cut: ₦${(price * adminFraction).toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF5A5BFF), fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
        );
      }
    );
  }
}