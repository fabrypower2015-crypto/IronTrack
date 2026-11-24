import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// Onboarding iniziale in 4 passaggi: profilo, obiettivo, livello/frequenza
/// e proposta automatica della scheda di allenamento più adatta.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();

  int _step = 0;
  String _unit = 'kg';
  String _goal = 'Massa';
  String _level = 'Intermedio';
  int _weeklyDays = 3;

  static const List<({String id, String subtitle, IconData icon})> _goals = [
    (
      id: 'Massa',
      subtitle: 'Aumentare volume muscolare e ipertrofia',
      icon: Icons.fitness_center_rounded,
    ),
    (
      id: 'Forza',
      subtitle: 'Migliorare i massimali sui fondamentali',
      icon: Icons.bolt_rounded,
    ),
    (
      id: 'Definizione',
      subtitle: 'Ridurre massa grassa mantenendo i carichi',
      icon: Icons.local_fire_department_rounded,
    ),
    (
      id: 'Ricomposizione',
      subtitle: 'Costruire tono e forma fisica equilibrata',
      icon: Icons.auto_awesome_rounded,
    ),
  ];

  static const List<({String id, String subtitle})> _levels = [
    (id: 'Principiante', subtitle: 'Meno di 1 anno di allenamento costante'),
    (id: 'Intermedio', subtitle: '1–3 anni di palestra con progressioni regolari'),
    (id: 'Avanzato', subtitle: 'Oltre 3 anni, programmazione strutturata'),
  ];

  /// Determina la scheda consigliata dai template preinstallati in base ai giorni.
  ({String title, String description, String split}) get _recommendedSplit {
    if (_weeklyDays <= 3) {
      return (
        title: 'Full Body Bilanciata',
        split: '3 giorni / settimana (Lun - Mer - Ven)',
        description:
            'Allena tutto il corpo in ogni seduta: massima frequenza muscolare e progressione lineare ideale per $_weeklyDays giorni.',
      );
    }
    if (_weeklyDays == 4) {
      return (
        title: 'Upper / Lower Split',
        split: '4 giorni / settimana (Lun - Mar - Gio - Ven)',
        description:
            'Alterna parte superiore e parte inferiore per bilanciare volume, carichi pesanti e recupero ottimale.',
      );
    }
    return (
      title: 'Push / Pull / Legs (PPL)',
      split: '$_weeklyDays giorni / settimana',
      description:
          'Divide i muscoli per schema motorio (Spinta, Tirata, Gambe) permettendo alto volume mirato e massima specializzazione.',
    );
  }

  void _nextStep() {
    if (_step < 3) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    final app = context.read<AppProvider>();
    await app.completeOnboarding(
      name: _nameController.text,
      goal: _goal,
      level: _level,
      weeklyGoal: _weeklyDays,
      unit: _unit,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rec = _recommendedSplit;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Barra avanzamento step
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / 4,
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_step + 1}/4',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Contenuto pagine onboarding
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // STEP 1: Benvenuto, nome e unità
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.primary.alphaPct(0.15),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.fitness_center_rounded,
                            size: 40,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Benvenuto in IronTrack',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Il tuo diario di palestra 100% offline: allenamenti, record, grafici e misure fisiche sempre sul telefono.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Come vuoi essere chiamato?',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Es. Marco',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Unità di misura preferita',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'kg', label: Text('Chilogrammi (kg)')),
                            ButtonSegment(value: 'lb', label: Text('Libbre (lb)')),
                          ],
                          selected: {_unit},
                          onSelectionChanged: (set) =>
                              setState(() => _unit = set.first),
                        ),
                      ],
                    ),
                  ),

                  // STEP 2: Obiettivo principale
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qual è il tuo obiettivo?',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Personalizzeremo i consigli e la dashboard sul tuo focus principale.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        ..._goals.map((g) {
                          final selected = _goal == g.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => setState(() => _goal = g.id),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: selected
                                      ? cs.primary.alphaPct(0.14)
                                      : cs.surface,
                                  border: Border.all(
                                    color: selected
                                        ? cs.primary
                                        : cs.outlineVariant.alphaPct(0.5),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      g.icon,
                                      size: 28,
                                      color: selected
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            g.id,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            g.subtitle,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Icon(Icons.check_circle, color: cs.primary),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  // STEP 3: Livello e giorni a settimana
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Livello e frequenza',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Esperienza in palestra',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        ..._levels.map((lvl) {
                          final selected = _level == lvl.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: selected
                                      ? cs.primary
                                      : cs.outlineVariant.alphaPct(0.4),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: ListTile(
                                title: Text(
                                  lvl.id,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(lvl.subtitle),
                                trailing: selected
                                    ? Icon(Icons.check_circle,
                                        color: cs.primary)
                                    : null,
                                onTap: () => setState(() => _level = lvl.id),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Obiettivo giorni a settimana',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '$_weeklyDays giorni',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _weeklyDays.toDouble(),
                          min: 2,
                          max: 6,
                          divisions: 4,
                          label: '$_weeklyDays giorni',
                          onChanged: (v) =>
                              setState(() => _weeklyDays = v.round()),
                        ),
                      ],
                    ),
                  ),

                  // STEP 4: Riepilogo e scheda consigliata
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Piano consigliato per te',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Abbiamo già precaricato 108 esercizi e 6 schede pronte che puoi modificare in qualsiasi momento.',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                cs.primary,
                                cs.primary.alphaPct(0.75),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.alphaPct(0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'SCHEDA CONSIGLIATA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                rec.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rec.split,
                                style: TextStyle(
                                  color: Colors.white.alphaPct(0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                rec.description,
                                style: TextStyle(
                                  color: Colors.white.alphaPct(0.92),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _summaryRow('Obiettivo', _goal),
                                const Divider(),
                                _summaryRow('Livello', _level),
                                const Divider(),
                                _summaryRow('Frequenza', '$_weeklyDays allenamenti / sett.'),
                                const Divider(),
                                _summaryRow('Unità peso', _unit.toUpperCase()),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Pulsante Avanti / Inizia
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _nextStep,
                  child: Text(_step == 3 ? 'Inizia ad allenarti' : 'Continua'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}