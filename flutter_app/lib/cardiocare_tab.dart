/// CardioCare Chat & Appointments Tab
///
/// HOW TO USE:
/// 1. Copy the /lib/screens/ and /lib/services/ folders into your Flutter project
/// 2. Add to pubspec.yaml:
///      http: ^1.2.0
///      socket_io_client: ^2.0.3+1
/// 3. After your user logs in, wrap this widget anywhere you want the tab:
///
///      CardioCareTab(
///        token: 'your-jwt-token',
///        userId: 'mongo-user-id',
///        fullName: 'Jane Doe',
///        role: 'patient', // or 'doctor'
///      )
///
/// 4. Change BASE_URL in lib/services/api_service.dart to your server IP.

import 'package:flutter/material.dart';
import 'screens/public_chat_screen.dart';
import 'screens/appointments_screen.dart';

class CardioCareTab extends StatefulWidget {
  final String token;
  final String userId;
  final String fullName;
  final String role; // 'patient' or 'doctor'

  const CardioCareTab({
    super.key,
    required this.token,
    required this.userId,
    required this.fullName,
    required this.role,
  });

  @override
  State<CardioCareTab> createState() => _CardioCareTabState();
}

class _CardioCareTabState extends State<CardioCareTab> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      PublicChatScreen(
        token: widget.token,
        userId: widget.userId,
        fullName: widget.fullName,
        role: widget.role,
      ),
      AppointmentsScreen(
        token: widget.token,
        userId: widget.userId,
        role: widget.role,
      ),
    ];

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: const Color(0xFFE53935).withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFFE53935)),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Color(0xFFE53935)),
            label: 'Appointments',
          ),
        ],
      ),
    );
  }
}
