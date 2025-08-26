import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;

import '../providers/bluetooth_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/device.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final BluetoothProvider provider = context.watch<BluetoothProvider>();
    // Threshold is controlled from Settings screen; no controller needed here

    const Color bgTop = Color(0xFF0B221A);
    const Color bgBottom = Color(0xFF0F2F22);
    const Color card = Color(0xFF143827);
    const Color accent = Color(0xFF2DC97A);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[bgTop, bgBottom],
            ),
          ),
          child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'BLE Distance',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  _UnitChip(accent: accent),
                  const SizedBox(width: 8),
                  _SettingsButton(onPressed: () => _openSettings(context))
                ],
              ),
              const SizedBox(height: 6),
              const Text('RSSI-Based Measurement', style: TextStyle(color: Colors.white70, letterSpacing: 0.2)),
              const SizedBox(height: 20),
              _GaugeCard(card: card, accent: accent),
              const SizedBox(height: 16),
              if (provider.connectedDevice == null)
                _ErrorBanner(
                  card: card,
                  message: _statusText(provider),
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _GradientButton(
                      onPressed: () => _openDevices(context),
                      icon: Icons.search,
                      label: 'Scan Devices',
                      gradient: LinearGradient(colors: <Color>[accent, accent.withValues(alpha: 0.8)]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GlassButton(onPressed: () => _openDevices(context), label: 'Devices'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // Removed unused _ask dialog helper
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({required this.card, required this.accent});
  final Color card;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final BluetoothProvider p = context.watch<BluetoothProvider>();
    final double size = 280;
    final String unit = p.useFeet ? 'feet' : 'm';
    final double? distFeet = p.latestDistanceFeet;
    final double threshold = p.thresholdFeet;
    final double percent = distFeet == null ? 0 : (distFeet / threshold).clamp(0, 1);
    final Color glow = Color.lerp(Colors.redAccent, accent, 1 - percent) ?? accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: card.withValues(alpha: 0.7),
        boxShadow: <BoxShadow>[
          BoxShadow(color: glow.withValues(alpha: 0.2), blurRadius: 24, spreadRadius: 2, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: size,
            width: size,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                _GaugeRing(size: size, percent: percent, accent: accent, background: Colors.white10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: double.tryParse(p.formattedDistance) ?? 0),
                      duration: const Duration(milliseconds: 500),
                      builder: (_, double value, __) => Text(value.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    Text(unit, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text('RSSI: ${p.latestRssi ?? 0} dBm', style: const TextStyle(color: Colors.white70, fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()])),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final BluetoothProvider p = context.watch<BluetoothProvider>();
    return InkWell(
      onTap: () => p.toggleUnit(),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(22)),
        child: Text(p.useFeet ? 'ft' : 'm', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.settings, color: Colors.white),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.card, required this.message});
  final Color card;
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: <Widget>[
        const Icon(Icons.circle, size: 10, color: Colors.redAccent),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
      ]),
    );
  }
}

class _GaugeRing extends StatelessWidget {
  const _GaugeRing({required this.size, required this.percent, required this.accent, required this.background});
  final double size; final double percent; final Color accent; final Color background;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(percent: percent, accent: accent, background: background),
      size: Size.square(size),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percent, required this.accent, required this.background});
  final double percent; final Color accent; final Color background;
  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 10;
    final Paint bg = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, bg);

    final SweepGradient grad = SweepGradient(colors: <Color>[accent.withValues(alpha: 0.2), accent, accent], stops: const <double>[0.0, 0.9, 1.0]);
    final Paint fg = Paint()
      ..shader = grad.createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final double sweep = 2 * 3.1415926535 * percent;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -3.1415926535 / 2, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.percent != percent || oldDelegate.accent != accent;
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed, required this.icon, required this.label, required this.gradient});
  final VoidCallback onPressed; final IconData icon; final String label; final Gradient gradient;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14), boxShadow: const <BoxShadow>[BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.onPressed, required this.label});
  final VoidCallback onPressed; final String label;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
            alignment: Alignment.center,
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

String _statusText(BluetoothProvider p) {
  switch (p.adapterState) {
    case BluetoothAdapterState.on:
      return p.isScanning ? 'Scanning…' : 'Ready to scan';
    case BluetoothAdapterState.off:
      return 'Bluetooth is turned off';
    case BluetoothAdapterState.turningOn:
      return 'Bluetooth turning on…';
    case BluetoothAdapterState.turningOff:
      return 'Bluetooth turning off…';
    default:
      return 'Bluetooth status unknown';
  }
}

void _openDevices(BuildContext context) {
  final BluetoothProvider p = context.read<BluetoothProvider>();
  p.startScan();
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _DevicesPage()));
}

class _DevicesPage extends StatelessWidget {
  const _DevicesPage();
  @override
  Widget build(BuildContext context) {
    final BluetoothProvider p = context.watch<BluetoothProvider>();
    const Color bg = Color(0xFF0D2B1F);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('Available Devices'),
        actions: <Widget>[
          TextButton(onPressed: () => p.startScan(), child: const Text('Scan')),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: p.devices.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
        itemBuilder: (_, int i) {
          final DiscoveredDevice d = p.devices[i];
          return ListTile(
            title: Text(d.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text('RSSI: ${d.rssi} dBm', style: const TextStyle(color: Colors.white60)),
            trailing: ElevatedButton(onPressed: () { p.connect(d); Navigator.pop(context); }, child: const Text('Connect')),
            onTap: () { p.connect(d); Navigator.pop(context); },
          );
        },
      ),
    );
  }
}

void _openSettings(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _SettingsScreen()));
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();
  @override
  Widget build(BuildContext context) {
    final BluetoothProvider p = context.watch<BluetoothProvider>();
    final Color bg = const Color(0xFF0D2B1F);
    final Color card = const Color(0xFF143827);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _Section(title: 'Distance Settings', children: <Widget>[
            _Tile(card: card, title: 'Default Distance Unit', trailing: Switch(value: p.useFeet, onChanged: (_) => p.toggleUnit())),
            _Tile(card: card, title: 'Distance Alert Threshold', trailing: Text('${p.thresholdFeet.toStringAsFixed(1)} ft', style: const TextStyle(color: Colors.white))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
              child: Slider(value: p.thresholdFeet, min: 1, max: 30, onChanged: (double v) => p.updateThresholdFeet(v)),
            ),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Audio Settings', children: <Widget>[
            _Tile(card: card, title: 'Audio Feedback', subtitle: 'Play audio when distance threshold is reached', trailing: Switch(value: p.audioFeedbackEnabled, onChanged: p.setAudioFeedback)),
            _Tile(card: card, title: 'Audio Volume', trailing: Text('${(p.audioVolume * 100).round()}%', style: const TextStyle(color: Colors.white))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
              child: Slider(value: p.audioVolume, onChanged: p.setAudioVolume),
            ),
          ]),
          const SizedBox(height: 16),
          _Section(title: 'Auto-Connect Settings', children: <Widget>[
            _Tile(card: card, title: 'Auto-Connect to Saved Devices', trailing: Switch(value: p.autoConnectEnabled, onChanged: p.setAutoConnect)),
            _Tile(card: card, title: 'Auto-Connect Status', trailing: Icon(p.autoConnectEnabled ? Icons.check_circle : Icons.cancel, color: p.autoConnectEnabled ? Colors.greenAccent : Colors.redAccent)),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title; final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      ...children,
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.card, required this.title, this.subtitle, required this.trailing});
  final Color card; final String title; final String? subtitle; final Widget trailing;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
      child: Row(children: <Widget>[
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white60)),
        ])),
        trailing,
      ]),
    );
  }
}


