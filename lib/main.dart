import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:distance_measurement/providers/bluetooth_provider.dart';
import 'package:distance_measurement/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BluetoothProvider(),
      child: MaterialApp(
        title: 'Distance Measurement',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
} 