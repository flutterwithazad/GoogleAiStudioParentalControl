import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_mirror_shared/logging/app_logger.dart';
import '../services/child_platform_bridge.dart';

class ChildSetupScreen extends StatefulWidget {
  final ChildPlatformBridge platformBridge;
  final VoidCallback onPairingComplete;

  const ChildSetupScreen({
    super.key,
    required this.platformBridge,
    required this.onPairingComplete,
  });

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends State<ChildSetupScreen> {
  late String _pairingCode;
  bool _isExempt = false;

  @override
  void initState() {
    super.initState();
    _generateCode();
    _checkBattery();
  }

  void _generateCode() {
    final random = Random();
    _pairingCode = (100000 + random.nextInt(900000)).toString();
    AppLogger.signaling('Generated setup pairing code: $_pairingCode');
  }

  Future<void> _checkBattery() async {
    final exempt = await widget.platformBridge.checkBatteryOptimization();
    if (mounted) setState(() => _isExempt = exempt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Child Device Setup', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Pair with Parent Device',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan this QR code from the Parent App or enter the 6-digit setup code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            const SizedBox(height: 24),

            // QR Code Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _pairingCode,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),

            const SizedBox(height: 20),

            // Alphanumeric Code Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                _pairingCode,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Battery Optimization Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isExempt ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isExempt ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isExempt ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: _isExempt ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isExempt
                              ? 'Battery Optimization Disabled'
                              : 'Battery Exemption Recommended',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isExempt ? const Color(0xFF166534) : const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isExempt
                              ? 'Native capture service will remain active reliably in background.'
                              : 'Allow app to run in background so remote mirroring works when UI is closed.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isExempt ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isExempt)
                    TextButton(
                      onPressed: () async {
                        await widget.platformBridge.requestBatteryOptimizationExemption();
                        await _checkBattery();
                      },
                      child: const Text('Allow'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  widget.onPairingComplete();
                },
                child: const Text(
                  'Complete Setup',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
