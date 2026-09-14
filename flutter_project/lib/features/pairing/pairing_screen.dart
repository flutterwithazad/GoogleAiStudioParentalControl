import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/device_service.dart';

class PairingScreen extends StatefulWidget {
  final DeviceService deviceService;
  final bool isChild;
  final Function(String code)? onPairParentWithCode;

  const PairingScreen({
    super.key,
    required this.deviceService,
    required this.isChild,
    this.onPairParentWithCode,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _codeController = TextEditingController();
  String _childPairingCode = '684-219';
  bool _isPairing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isChild) {
      _generatePairingCode();
    }
  }

  void _generatePairingCode() {
    final devId = widget.deviceService.deviceInfo?.deviceId ?? 'CHILD';
    final hash = devId.hashCode.abs() % 900000 + 100000;
    setState(() {
      _childPairingCode = '${hash.toString().substring(0, 3)}-${hash.toString().substring(3)}';
    });
  }

  void _handlePairSubmit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isPairing = true);
    await Future.delayed(const Duration(milliseconds: 800)); // Simulated server verification

    if (widget.onPairParentWithCode != null) {
      widget.onPairParentWithCode!(code);
    }
    if (mounted) {
      setState(() => _isPairing = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.isChild ? 'Pair Child Device' : 'Pair New Child Device'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: widget.isChild ? _buildChildPairingUI() : _buildParentPairingUI(),
        ),
      ),
    );
  }

  Widget _buildChildPairingUI() {
    final deviceId = widget.deviceService.deviceInfo?.deviceId ?? 'child_unknown';
    final payload = 'screenmirror://pair?device_id=$deviceId&code=$_childPairingCode';

    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Scan this QR code from the Parent App',
          style: TextStyle(fontSize: 16, color: Color(0xFF334155)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 220.0,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Or enter this 6-digit code on the Parent App:', style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Text(
          _childPairingCode,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }

  Widget _buildParentPairingUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Pairing Code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the 6-digit code shown on the Child device screen.',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g. 684-219',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isPairing ? null : _handlePairSubmit,
            child: _isPairing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Connect & Authorize Device', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
