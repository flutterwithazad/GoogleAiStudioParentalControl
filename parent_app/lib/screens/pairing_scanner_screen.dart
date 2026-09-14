import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:screen_mirror_shared/logging/app_logger.dart';

class PairingScannerScreen extends StatefulWidget {
  final Function(String code) onCodePaired;

  const PairingScannerScreen({super.key, required this.onCodePaired});

  @override
  State<PairingScannerScreen> createState() => _PairingScannerScreenState();
}

class _PairingScannerScreenState extends State<PairingScannerScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isProcessing = false;

  void _submitCode(String code) {
    if (_isProcessing || code.trim().isEmpty) return;
    setState(() => _isProcessing = true);
    AppLogger.signaling('Submitting pairing code: ${code.trim()}');
    widget.onCodePaired(code.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pair Child Device', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: Column(
        children: [
          // QR Scanner Viewport
          Expanded(
            flex: 3,
            child: ClipRRect(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null && !_isProcessing) {
                      _submitCode(barcode.rawValue!);
                      break;
                    }
                  }
                },
              ),
            ),
          ),

          // Manual code fallback
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Or Enter 6-Digit Setup Code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '123456',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: _submitCode,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _submitCode(_codeController.text),
                      child: const Text('Confirm Pairing'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
