import 'package:flutter/material.dart';

class ZiannaMain extends StatelessWidget {
  const ZiannaMain({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink.shade50,

      appBar: AppBar(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        title: const Text("Zianna"),
        centerTitle: true,
      ),

      body: const Center(
        child: Text(
          "Zianna Main Screen",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}