import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Centro Strumenti Palestra & Traguardi:
/// 0: Calcolatore Dischi Bilanciere
/// 1: Calcolatore 1RM + Percentuali + Rampa Riscaldamento
/// 2: Timer Tabata / EMOM / HIIT
/// 3: Obiettivi personali con barra progresso
/// 4: Badge e Traguardi
class ToolsScreen extends StatefulWidget {
  final int initialTabIndex;

  const ToolsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stato Calcolatore Dischi
  final TextEditingController _plateTargetCtrl =
      TextEditingController(text: '100');
  double _barbellWeight = 20.0;
  final Set<double> _enabledKgPlates = {25, 20, 15, 10, 5, 2.5, 1.25};

  // Stato Calcolatore 1RM & Riscaldamento
  final TextEditingController _rmWeightCtrl = TextEditingController(text: '80');
  final TextEditingController _rmRepsCtrl = TextEditingController(text: '6');

  // Stato Timer Tabata / EMOM
  int _hiitWorkSec = 30;
  int _hiitRestSec = 15;
  int _hiitRounds = 8;
  int _currentRound = 1;
  bool _isWorkPhase = true;
  int _hiitRemaining = 30;
  bool _hiitRunning = false;
  Timer? _hiitTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _hiitTimer?.cancel();
    _tabController.dispose();
    _plateTargetCtrl.dispose();
    _rmWeightCtrl.dispose();
    _rmRepsCtrl.dispose();
    super.dispose();
  }

  void _startOrPauseHiit() {
    if (_hiitRunning) {
      _hiitTimer?.cancel();
      setState(() => _hiitRunning = false);
      return;
    }

    setState(() => _hiitRunning = true);
    _hiitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_hiitRemaining > 1) {
        setState(() => _hiitRemaining--);
      } else {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        if (_isWorkPhase && _hiitRestSec > 0) {
          setState(() {
            _isWorkPhase = false;
            _hiitRemaining = _hiitRestSec;
          });
        } else if (_currentRound < _hiitRounds) {
          setState(() {
            _currentRound++;
            _isWorkPhase = true;
            _hiitRemaining = _hiitWorkSec;
          });
        } else {
          timer.cancel();
          setState(() {
            _hiitRunning = false;
            _hiitRemaining = 0;
          });
        }
      }
    });
  }

  void _resetHiit() {
    _hiitTimer?.cancel();
    setState(() {
      _hiitRunning = false;
      _currentRound = 1;
      _isWorkPhase = true;
      _hiitRemaining = _hiitWorkSec;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strumenti & Traguardi'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Dischi'),
            Tab(text: '1RM & Risc.'),
            Tab(text: 'Tabata/HIIT'),
            Tab(text: 'Obiettivi'),
            Tab(text: 'Badge'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPlateCalculatorTab(app),
          _buildOneRmTab(app),
          _buildHiitTimerTab(),
          _buildGoalsTab(app),
          _buildBadgesTab(app),
        ],
      ),
    );
  }

  // ==================== TAB 0: CALCOLATORE DISCHI BILANCIERE ====================

  Widget _buildPlateCalculatorTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;
    final target =
        double.tryParse(_plateTargetCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final available = unit == 'lb'
        ? const [45.0, 35.0, 25.0, 10.0, 5.0, 2.5]
        : _enabledKgPlates.toList();
    final bar = unit == 'lb' && _barbellWeight == 20 ? 45.0 : _barbellWeight;

    final result = AnalyticsService.calculateBarbellPlates(
      targetWeight: target,
      barbellWeight: bar,
      availablePlates: available,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _plateTargetCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Carico totale desiderato ($unit)',
                    prefixIcon: const Icon(Icons.fitness_center_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Peso bilanciere',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (unit == 'lb' ? [45.0, 35.0, 25.0] : [20.0, 15.0, 10.0])
                      .map((w) => ChoiceChip(
                            label: Text('${w.round()} $unit'),
                            selected: bar == w,
                            onSelected: (_) =>
                                setState(() => _barbellWeight = w),
                          ))
                      .toList(),
                ),
                if (unit == 'kg') ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Dischi disponibili in palestra (kg)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25].map((p) {
                      final active = _enabledKgPlates.contains(p);
                      return FilterChip(
                        label: Text(p % 1 == 0 ? '${p.round()}' : '$p'),
                        selected: active,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _enabledKgPlates.add(p);
                            } else if (_enabledKgPlates.length > 1) {
                              _enabledKgPlates.remove(p);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Visualizzazione grafica del bilanciere carico
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  'Carico reale: ${result.achievedWeight.toStringAsFixed(1)} $unit',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Per ciascun lato (${((result.achievedWeight - bar) / 2).toStringAsFixed(2)} $unit)',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 22),

                // Disegno bilanciere con dischi colorati
                SizedBox(
                  height: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Dischi lato sinistro (ordine inverso)
                      ...result.platesPerSide.reversed
                          .map((p) => _plateVisual(p)),
                      // Barra centrale
                      Container(
                        width: 72,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade500,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Dischi lato destro
                      ...result.platesPerSide.map((p) => _plateVisual(p)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (result.platesPerSide.isEmpty)
                  const Text('Solo bilanciere scarico.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: result.platesPerSide
                        .map((p) => Chip(
                              avatar: Icon(
                                Icons.circle,
                                size: 12,
                                color: _plateColor(p),
                              ),
                              label: Text(
                                '${p % 1 == 0 ? p.round() : p} $unit',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _plateVisual(double weight) {
    final height = (34 + weight * 2.2).clamp(38.0, 90.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      width: 12,
      height: height,
      decoration: BoxDecoration(
        color: _plateColor(weight),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Color _plateColor(double w) {
    if (w >= 25) return const Color(0xFFDC2626);
    if (w >= 20) return const Color(0xFF2563EB);
    if (w >= 15) return const Color(0xFFEAB308);
    if (w >= 10) return const Color(0xFF16A34A);
    if (w >= 5) return const Color(0xFF94A3B8);
    return const Color(0xFF475569);
  }

  // ==================== TAB 1: CALCOLATORE 1RM & RISCALDAMENTO ====================

  Widget _buildOneRmTab(AppProvider app) {
    final unit = app.profile.unit;
    final cs = Theme.of(context).colorScheme;
    final w = double.tryParse(_rmWeightCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final reps = int.tryParse(_rmRepsCtrl.text) ?? 0;

    final calc = AnalyticsService.calculateOneRepMax(w, reps);
    final warmupRamp = AnalyticsService.generateWarmupRamp(
      AnalyticsService.toStorageKg(w, unit),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rmWeightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: 'Peso ($unit)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _rmRepsCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Ripetizioni'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Stime Epley e Brzycki
        Row(
          children: [
            Expanded(
              child: KpiCard(
                icon: Icons.bolt_rounded,
                label: '1RM Epley',
                value: '${calc.epley.toStringAsFixed(1)} $unit',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: KpiCard(
                icon: Icons.analytics_outlined,
                iconColor: const Color(0xFF10B981),
                label: '1RM Brzycki',
                value: '${calc.brzycki.toStringAsFixed(1)} $unit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tabella percentuali di carico
        const SectionHeader(title: 'Tabella percentuali 1RM'),
        Card(
          child: Column(
            children: calc.percentages.entries.map((e) {
              return ListTile(
                dense: true,
                title: Text(
                  '${e.key}% del massimale',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: Text(
                  '${e.value.toStringAsFixed(1)} $unit',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: cs.primary,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Rampa di riscaldamento suggerita
        const SectionHeader(title: 'Rampa di riscaldamento suggerita'),
        Card(
          child: Column(
            children: warmupRamp.asMap().entries.map((e) {
              final s = e.value;
              return ListTile(
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFF59E0B).alphaPct(0.18),
                  child: Text(
                    'R${e.key + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
                title: Text(
                  '${AnalyticsService.formatWeight(s.weightKg, unit)} × ${s.reps} rip.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${s.percent}% del carico target'),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==================== TAB 2: TIMER TABATA / EMOM / HIIT ====================

  Widget _buildHiitTimerTab() {
    final cs = Theme.of(context).colorScheme;
    final phaseColor =
        _isWorkPhase ? cs.primary : const Color(0xFF10B981);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Preset rapidi Tabata / EMOM
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('Tabata (20s/10s × 8)'),
              onPressed: () {
                _hiitTimer?.cancel();
                setState(() {
                  _hiitWorkSec = 20;
                  _hiitRestSec = 10;
                  _hiitRounds = 8;
                  _currentRound = 1;
                  _isWorkPhase = true;
                  _hiitRemaining = 20;
                  _hiitRunning = false;
                });
              },
            ),
            ActionChip(
              label: const Text('EMOM (60s × 10)'),
              onPressed: () {
                _hiitTimer?.cancel();
                setState(() {
                  _hiitWorkSec = 60;
                  _hiitRestSec = 0;
                  _hiitRounds = 10;
                  _currentRound = 1;
                  _isWorkPhase = true;
                  _hiitRemaining = 60;
                  _hiitRunning = false;
                });
              },
            ),
            ActionChip(
              label: const Text('HIIT (40s/20s × 6)'),
              onPressed: () {
                _hiitTimer?.cancel();
                setState(() {
                  _hiitWorkSec = 40;
                  _hiitRestSec = 20;
                  _hiitRounds = 6;
                  _currentRound = 1;
                  _isWorkPhase = true;
                  _hiitRemaining = 40;
                  _hiitRunning = false;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Display principale del cronometro
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: phaseColor.alphaPct(0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isWorkPhase ? 'LAVORO' : 'RECUPERO',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: phaseColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  AnalyticsService.formatClock(_hiitRemaining),
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: phaseColor,
                    letterSpacing: -1.5,
                  ),
                ),
                Text(
                  'Round $_currentRound di $_hiitRounds',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _startOrPauseHiit,
                      icon: Icon(_hiitRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      label: Text(_hiitRunning ? 'Pausa' : 'Avvia'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _resetHiit,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Regolazione manuale intervalli
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _stepperRow('Lavoro (sec)', _hiitWorkSec, 5, (v) {
                  setState(() {
                    _hiitWorkSec = v.clamp(10, 300);
                    if (!_hiitRunning && _isWorkPhase) {
                      _hiitRemaining = _hiitWorkSec;
                    }
                  });
                }),
                const Divider(),
                _stepperRow('Riposo (sec)', _hiitRestSec, 5, (v) {
                  setState(() => _hiitRestSec = v.clamp(0, 180));
                }),
                const Divider(),
                _stepperRow('Numero round', _hiitRounds, 1, (v) {
                  setState(() => _hiitRounds = v.clamp(1, 30));
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepperRow(
    String label,
    int value,
    int step,
    void Function(int next) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        IconButton(
          onPressed: () => onChanged(value - step),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value + step),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  // ==================== TAB 3: OBIETTIVI PERSONALI ====================

  Widget _buildGoalsTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openGoalDialog(app),
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Nuovo obiettivo'),
          ),
        ),
        const SizedBox(height: 14),
        if (app.goals.isEmpty)
          const EmptyStateView(
            icon: Icons.flag_outlined,
            title: 'Nessun obiettivo impostato',
            subtitle:
                'Crea un traguardo come "Panca 100 kg" o "Peso 75 kg" per monitorarlo con barra di progresso.',
          )
        else
          ...app.goals.map((g) {
            final pct = (g.progressRatio * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            g.isCompleted
                                ? Icons.verified_rounded
                                : Icons.flag_rounded,
                            color: g.isCompleted
                                ? const Color(0xFF10B981)
                                : cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              g.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              if (g.id != null) app.deleteGoal(g.id!);
                            },
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Attuale: ${g.currentValue.toStringAsFixed(1)} ${g.unit}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Target: ${g.targetValue.toStringAsFixed(1)} ${g.unit} ($pct%)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: g.progressRatio,
                          minHeight: 9,
                          color: g.isCompleted
                              ? const Color(0xFF10B981)
                              : cs.primary,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  /// Finestra di creazione di un nuovo obiettivo (collegato a esercizio, peso, allenamenti o libero).
  Future<void> _openGoalDialog(AppProvider app) async {
    final unit = app.profile.unit;
    String type = 'exercise_weight';
    Exercise? selectedEx = app.exercises.isNotEmpty ? app.exercises.first : null;
    final titleCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '60');
    final targetCtrl = TextEditingController(text: '100');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Crea obiettivo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Tipo obiettivo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'exercise_weight',
                      child: Text('Carico su esercizio (PR)'),
                    ),
                    DropdownMenuItem(
                      value: 'body_weight',
                      child: Text('Peso corporeo'),
                    ),
                    DropdownMenuItem(
                      value: 'workouts_count',
                      child: Text('Numero allenamenti'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => type = v);
                  },
                ),
                const SizedBox(height: 10),
                if (type == 'exercise_weight')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ExercisePickerSheet.show(
                        ctx,
                        exercises: app.exercises,
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedEx = picked;
                          if (titleCtrl.text.isEmpty) {
                            titleCtrl.text =
                                '${picked.name} ${targetCtrl.text} $unit';
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.fitness_center_rounded),
                    label: Text(
                      selectedEx?.name ?? 'Scegli esercizio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Titolo obiettivo',
                    hintText: 'Es. Panca piana 100 kg',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Valore iniziale'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: targetCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Valore target'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final startVal =
          double.tryParse(startCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final targetVal =
          double.tryParse(targetCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final goalUnit = type == 'workouts_count' ? 'allen.' : 'kg';
      final isWeightType =
          type == 'exercise_weight' || type == 'body_weight';

      await app.saveGoal(FitnessGoal(
        title: titleCtrl.text.trim().isEmpty
            ? (selectedEx?.name ?? 'Nuovo obiettivo')
            : titleCtrl.text.trim(),
        type: type,
        exerciseId: type == 'exercise_weight' ? selectedEx?.id : null,
        startValue: isWeightType
            ? AnalyticsService.toStorageKg(startVal, unit)
            : startVal,
        targetValue: isWeightType
            ? AnalyticsService.toStorageKg(targetVal, unit)
            : targetVal,
        currentValue: isWeightType
            ? AnalyticsService.toStorageKg(startVal, unit)
            : startVal,
        unit: goalUnit,
        createdAt: DateTime.now(),
      ));
    }

    titleCtrl.dispose();
    startCtrl.dispose();
    targetCtrl.dispose();
  }

  // ==================== TAB 4: BADGE E TRAGUARDI ====================

  Widget _buildBadgesTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    final badges = AnalyticsService.calculateBadges(
      workouts: app.completedWorkouts,
      measurements: app.measurements,
      photos: app.photos,
    );
    final unlockedCount = badges.where((b) => b.unlocked).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).alphaPct(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFD97706),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount su ${badges.length} traguardi sbloccati',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: badges.isEmpty
                              ? 0
                              : unlockedCount / badges.length,
                          minHeight: 7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.96,
          ),
          itemBuilder: (_, idx) {
            final b = badges[idx];
            final color = b.unlocked ? const Color(0xFFD97706) : cs.outline;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.alphaPct(b.unlocked ? 0.18 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        badgeIconData(b.iconName),
                        size: 28,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      b.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: b.progress,
                        minHeight: 5,
                        color: b.unlocked ? const Color(0xFF10B981) : cs.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.unlocked ? 'Sbloccato!' : b.progressLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: b.unlocked
                            ? const Color(0xFF10B981)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}