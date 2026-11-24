import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Schermata di protezione opzionale tramite PIN a 4 cifre e/o biometria.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _enteredPin = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      if (app.profile.biometricEnabled) {
        app.authenticateWithBiometrics();
      }
    });
  }

  void _onDigitTap(String digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin += digit;
      _errorText = null;
    });

    if (_enteredPin.length == 4) {
      final app = context.read<AppProvider>();
      if (app.verifyPin(_enteredPin)) {
        app.unlockApp();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorText = 'PIN errato. Riprova.';
          _enteredPin = '';
        });
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final hasPin = app.profile.pinHash != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.primary.alphaPct(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, size: 38, color: cs.primary),
              ),
              const SizedBox(height: 18),
              Text(
                'IronTrack bloccato',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                hasPin
                    ? 'Inserisci il PIN a 4 cifre per accedere'
                    : 'Usa l\'impronta digitale per sbloccare',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // Indicatori cifre PIN
              if (hasPin) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? cs.primary : Colors.transparent,
                        border: Border.all(
                          color: filled ? cs.primary : cs.outline,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 20,
                  child: _errorText != null
                      ? Text(
                          _errorText!,
                          style: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 18),

                // Tastierino numerico
                SizedBox(
                  width: 270,
                  child: Column(
                    children: [
                      _buildRow(['1', '2', '3']),
                      const SizedBox(height: 12),
                      _buildRow(['4', '5', '6']),
                      const SizedBox(height: 12),
                      _buildRow(['7', '8', '9']),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: 72,
                            height: 60,
                            child: app.profile.biometricEnabled
                                ? IconButton(
                                    onPressed: app.authenticateWithBiometrics,
                                    icon: Icon(
                                      Icons.fingerprint_rounded,
                                      size: 32,
                                      color: cs.primary,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          _digitButton('0'),
                          SizedBox(
                            width: 72,
                            height: 60,
                            child: IconButton(
                              onPressed: _onBackspace,
                              icon: const Icon(Icons.backspace_outlined),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: app.authenticateWithBiometrics,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Sblocca con biometria'),
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_digitButton).toList(),
    );
  }

  Widget _digitButton(String digit) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      height: 60,
      child: Material(
        color: cs.surfaceContainerHighest.alphaPct(0.55),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onDigitTap(digit),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}