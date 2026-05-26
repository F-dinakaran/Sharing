import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AppointmentsScreen extends StatefulWidget {
  final String token;
  final String userId;
  final String role; // 'patient' or 'doctor'

  const AppointmentsScreen({
    super.key,
    required this.token,
    required this.userId,
    required this.role,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ApiService _api;
  List<dynamic> _availableSlots = [];
  List<dynamic> _myAppointments = [];
  bool _loadingAvailable = true;
  bool _loadingMine = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.role == 'doctor' ? 2 : 2, vsync: this);
    _api = ApiService(widget.token);
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadAvailable(), _loadMine()]);
  }

  Future<void> _loadAvailable() async {
    setState(() => _loadingAvailable = true);
    final slots = await _api.getAvailableSlots();
    setState(() {
      _availableSlots = slots;
      _loadingAvailable = false;
    });
  }

  Future<void> _loadMine() async {
    setState(() => _loadingMine = true);
    final appts = await _api.getMyAppointments();
    setState(() {
      _myAppointments = appts;
      _loadingMine = false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = widget.role == 'doctor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: isDoctor ? 'Available Slots' : 'Book Appointment'),
            Tab(text: isDoctor ? 'My Schedule' : 'My Appointments'),
          ],
        ),
        actions: [
          if (isDoctor)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add availability',
              onPressed: _showCreateSlotDialog,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Tab 1 — available slots
          _loadingAvailable
              ? const Center(child: CircularProgressIndicator())
              : _availableSlots.isEmpty
                  ? _empty('No available slots right now')
                  : RefreshIndicator(
                      onRefresh: _loadAvailable,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _availableSlots.length,
                        itemBuilder: (_, i) => _buildAvailableCard(_availableSlots[i]),
                      ),
                    ),

          // Tab 2 — my appointments / schedule
          _loadingMine
              ? const Center(child: CircularProgressIndicator())
              : _myAppointments.isEmpty
                  ? _empty(isDoctor ? 'No appointments scheduled' : 'No bookings yet')
                  : RefreshIndicator(
                      onRefresh: _loadMine,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _myAppointments.length,
                        itemBuilder: (_, i) => _buildMyCard(_myAppointments[i]),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildAvailableCard(dynamic slot) {
    final doctor = slot['doctor'] ?? {};
    final doctorName = doctor['fullName'] ?? 'Unknown Doctor';
    final speciality = doctor['speciality'] ?? '';
    final date = slot['date'] ?? '';
    final time = slot['time'] ?? '';
    final duration = slot['duration'] ?? 30;
    final isDoctor = widget.role == 'doctor';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE53935).withOpacity(0.1),
              child: const Icon(Icons.medical_services, color: Color(0xFFE53935)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dr. $doctorName',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  if (speciality.isNotEmpty)
                    Text(speciality,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(date, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('$time · ${duration}min',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            if (!isDoctor)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showBookDialog(slot),
                child: const Text('Book'),
              ),
            if (isDoctor)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteSlot(slot['_id']),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyCard(dynamic slot) {
    final isDoctor = widget.role == 'doctor';
    final date = slot['date'] ?? '';
    final time = slot['time'] ?? '';
    final duration = slot['duration'] ?? 30;
    final status = slot['status'] ?? 'available';
    final reason = slot['reason'] ?? '';

    String personName = '';
    String personLabel = '';
    if (isDoctor && slot['bookedBy'] != null) {
      personName = slot['bookedBy']['fullName'] ?? '';
      personLabel = 'Patient';
    } else if (!isDoctor && slot['doctor'] != null) {
      personName = slot['doctor']['fullName'] ?? '';
      personLabel = 'Dr.';
    }

    final isBooked = status == 'booked';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (personName.isNotEmpty)
                        Text('$personLabel $personName',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(date, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('$time · ${duration}min',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBooked
                        ? Colors.orange.withOpacity(0.15)
                        : Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isBooked ? 'Booked' : 'Available',
                    style: TextStyle(
                      color: isBooked ? Colors.orange[800] : Colors.green[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notes, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(reason,
                            style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _empty(String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(msg, style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );

  // ─── Book dialog ─────────────────────────────────────────
  void _showBookDialog(dynamic slot) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Book Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${slot['date']} at ${slot['time']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Dr. ${slot['doctor']?['fullName'] ?? ''}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for visit (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              final result = await _api.bookSlot(slot['_id'], reasonCtrl.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result['message'] ?? 'Done'),
                  backgroundColor: result['slot'] != null ? Colors.green : Colors.red,
                ));
                if (result['slot'] != null) _loadAll();
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ─── Doctor: create availability ─────────────────────────
  void _showCreateSlotDialog() {
    String date = '';
    String startTime = '09:00';
    String endTime = '17:00';
    int duration = 30;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add Availability'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => date = v,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                          labelText: 'Start', border: OutlineInputBorder()),
                      controller: TextEditingController(text: startTime),
                      onChanged: (v) => startTime = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                          labelText: 'End', border: OutlineInputBorder()),
                      controller: TextEditingController(text: endTime),
                      onChanged: (v) => endTime = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: duration,
                decoration: const InputDecoration(
                    labelText: 'Slot duration', border: OutlineInputBorder()),
                items: [15, 20, 30, 45, 60]
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d min')))
                    .toList(),
                onChanged: (v) => setLocal(() => duration = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final result = await _api.createAvailability(
                  date: date,
                  startTime: startTime,
                  endTime: endTime,
                  duration: duration,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['message'] ?? 'Done'),
                    backgroundColor:
                        result['slots'] != null ? Colors.green : Colors.red,
                  ));
                  if (result['slots'] != null) _loadAll();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSlot(String slotId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Slot'),
        content: const Text('Remove this availability slot?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final result = await _api.deleteSlot(slotId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Done'),
        ));
        _loadAll();
      }
    }
  }
}
