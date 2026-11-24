import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'active_workout_screen.dart';

/// Schermata Esercizi e Schede:
/// - Tab 1: Schede / Routine (creazione, modifica, giorni settimanali, template, avvio)
/// - Tab 2: Libreria Esercizi (108 precompilati + CRUD personalizzati con filtri)
class ExercisesRoutinesScreen extends StatefulWidget {
  const ExercisesRoutinesScreen({super.key});

  @override
  State<ExercisesRoutinesScreen> createState() =>
      _ExercisesRoutinesScreenState();
}

class _ExercisesRoutinesScreenState extends State<ExercisesRoutinesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _exerciseSearch = '';
  String _selectedMuscle = 'Tutti';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Apre l'editor per creare o modificare un esercizio nella libreria.
  Future<void> _openExerciseEditor(AppProvider app, {Exercise? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String muscle = existing?.muscleGroup ?? MuscleGroups.petto;
    String equipment = existing?.equipment ?? EquipmentTypes.all.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text(
            existing == null ? 'Nuovo esercizio' : 'Modifica esercizio',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome esercizio',
                    hintText: 'Es. Chest press monolaterale',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: muscle,
                  decoration: const InputDecoration(
                    labelText: 'Gruppo muscolare',
                  ),
                  items: MuscleGroups.all
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => muscle = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: EquipmentTypes.all.contains(equipment)
                      ? equipment
                      : EquipmentTypes.all.last,
                  decoration: const InputDecoration(labelText: 'Attrezzo'),
                  items: EquipmentTypes.all
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => equipment = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note tecniche (opzionale)',
                  ),
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
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      if (existing == null) {
        await app.addExercise(Exercise(
          name: nameCtrl.text.trim(),
          muscleGroup: muscle,
          equipment: equipment,
          isCustom: true,
          notes: notesCtrl.text.trim(),
        ));
      } else {
        await app.updateExercise(existing.copyWith(
          name: nameCtrl.text.trim(),
          muscleGroup: muscle,
          equipment: equipment,
          notes: notesCtrl.text.trim(),
        ));
      }
    }

    nameCtrl.dispose();
    notesCtrl.dispose();
  }

  /// Conferma eliminazione di un esercizio.
  Future<void> _confirmDeleteExercise(AppProvider app, Exercise ex) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare esercizio?'),
        content: Text(
          'Vuoi eliminare "${ex.name}"? Verrà rimosso anche dalle schede collegate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok == true && ex.id != null) {
      await app.deleteExercise(ex.id!);
    }
  }

  /// Apre la schermata completa di creazione/modifica di una scheda.
  Future<void> _openRoutineEditor({Routine? routine}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RoutineEditorScreen(existingRoutine: routine),
      ),
    );
  }

  Future<void> _confirmDeleteRoutine(AppProvider app, Routine routine) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare scheda?'),
        content: Text('Vuoi eliminare la scheda "${routine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok == true && routine.id != null) {
      await app.deleteRoutine(routine.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Esercizi & Schede'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Schede (${app.routines.length})'),
            Tab(text: 'Libreria (${app.exercises.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoutinesTab(app),
          _buildExercisesTab(app),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _openRoutineEditor();
          } else {
            _openExerciseEditor(app);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _tabController.index == 0 ? 'Nuova scheda' : 'Nuovo esercizio',
        ),
      ),
    );
  }

  Widget _buildRoutinesTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;

    if (app.routines.isEmpty) {
      return EmptyStateView(
        icon: Icons.assignment_outlined,
        title: 'Nessuna scheda presente',
        subtitle: 'Crea la tua prima scheda di allenamento personalizzata.',
        buttonLabel: 'Crea scheda',
        onPressed: () => _openRoutineEditor(),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        app.activeWorkout != null ? 150 : 92,
      ),
      itemCount: app.routines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = app.routines[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  r.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (r.isTemplate) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primary.alphaPct(0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'TEMPLATE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (r.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              r.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (act) {
                        if (act == 'edit') {
                          _openRoutineEditor(routine: r);
                        } else if (act == 'delete') {
                          _confirmDeleteRoutine(app, r);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Modifica scheda'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Elimina',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Giorni della settimana assegnati
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(7, (i) {
                    final dayNum = i + 1;
                    final active = r.weekdays.contains(dayNum);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: active
                            ? cs.primary
                            : cs.surfaceContainerHighest.alphaPct(0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AnalyticsService.weekdayShortNames[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  }),
                ),
                const Divider(height: 20),
                // Anteprima esercizi della scheda
                ...r.exercises.take(5).map((rex) {
                  final exName =
                      app.exerciseMap[rex.exerciseId]?.name ?? 'Esercizio';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            exName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${rex.targetSets} × ${rex.targetReps}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (r.exercises.length > 5)
                  Text(
                    '+ altri ${r.exercises.length - 5} esercizi',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openRoutineEditor(routine: r),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Modifica'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (app.activeWorkout == null) {
                            await app.startWorkout(routine: r);
                          }
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ActiveWorkoutScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Inizia'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExercisesTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;
    final prs = AnalyticsService.calculatePersonalRecords(
      app.completedWorkouts,
      app.exerciseMap,
    );
    final prByEx = {for (final p in prs) p.exerciseId: p};

    final filtered = app.exercises.where((e) {
      final matchesMuscle =
          _selectedMuscle == 'Tutti' || e.muscleGroup == _selectedMuscle;
      final q = _exerciseSearch.trim().toLowerCase();
      final matchesText = q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.equipment.toLowerCase().contains(q) ||
          e.muscleGroup.toLowerCase().contains(q);
      return matchesMuscle && matchesText;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _exerciseSearch = v),
            decoration: const InputDecoration(
              hintText: 'Cerca tra gli esercizi (nome o attrezzo)...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ['Tutti', ...MuscleGroups.all].map((m) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(m),
                  selected: _selectedMuscle == m,
                  onSelected: (_) => setState(() => _selectedMuscle = m),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyStateView(
                  icon: Icons.search_off_rounded,
                  title: 'Nessun esercizio trovato',
                  subtitle: 'Crea un esercizio personalizzato con il pulsante +.',
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    app.activeWorkout != null ? 150 : 92,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final ex = filtered[idx];
                    final color = muscleGroupColor(ex.muscleGroup);
                    final pr = ex.id != null ? prByEx[ex.id!] : null;

                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.alphaPct(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            muscleGroupIcon(ex.muscleGroup),
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ex.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (ex.isCustom)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.primary.alphaPct(0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'CUSTOM',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${ex.muscleGroup} • ${ex.equipment}'),
                            if (pr != null)
                              Text(
                                'PR: ${AnalyticsService.formatWeight(pr.maxWeightKg, unit)} × ${pr.repsAtMaxWeight} (1RM ${AnalyticsService.formatWeight(pr.best1RmKg, unit)})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (act) {
                            if (act == 'edit') {
                              _openExerciseEditor(app, existing: ex);
                            } else if (act == 'delete') {
                              _confirmDeleteExercise(app, ex);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Modifica'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Elimina',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Editor completo per creare o modificare una scheda/routine.
class _RoutineEditorScreen extends StatefulWidget {
  final Routine? existingRoutine;

  const _RoutineEditorScreen({this.existingRoutine});

  @override
  State<_RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<_RoutineEditorScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late Set<int> _selectedDays;
  late List<RoutineExercise> _items;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRoutine;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _selectedDays = Set<int>.from(r?.weekdays ?? const []);
    _items = List<RoutineExercise>.from(r?.exercises ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _addExercise(AppProvider app) async {
    final chosen = await ExercisePickerSheet.show(
      context,
      exercises: app.exercises,
      title: 'Aggiungi esercizio alla scheda',
    );
    if (chosen != null && chosen.id != null) {
      setState(() {
        _items.add(RoutineExercise(
          routineId: widget.existingRoutine?.id ?? 0,
          exerciseId: chosen.id!,
          orderIndex: _items.length,
          targetSets: 3,
          targetReps: '8-12',
          restSeconds: app.profile.defaultRestSeconds,
        ));
      });
    }
  }

  Future<void> _editRoutineExercise(int idx) async {
    final current = _items[idx];
    int sets = current.targetSets;
    final repsCtrl = TextEditingController(text: current.targetReps);
    int rest = current.restSeconds;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Target esercizio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Serie target',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Row(
                    children: [
                      IconButton(
                        onPressed: sets > 1
                            ? () => setModalState(() => sets--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '$sets',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      IconButton(
                        onPressed: sets < 12
                            ? () => setModalState(() => sets++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: repsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ripetizioni target',
                  hintText: 'Es. 8-10 oppure 12',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recupero',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    AnalyticsService.formatClock(rest),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Slider(
                value: rest.toDouble(),
                min: 30,
                max: 240,
                divisions: 14,
                onChanged: (v) => setModalState(() => rest = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Applica'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      setState(() {
        _items[idx] = current.copyWith(
          targetSets: sets,
          targetReps:
              repsCtrl.text.trim().isEmpty ? '8-12' : repsCtrl.text.trim(),
          restSeconds: rest,
        );
      });
    }
    repsCtrl.dispose();
  }

  Future<void> _save(AppProvider app) async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un nome per la scheda.')),
      );
      return;
    }

    final days = _selectedDays.toList()..sort();
    final routine = Routine(
      id: widget.existingRoutine?.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      weekdays: days,
      isTemplate: false,
      exercises: _items
          .asMap()
          .entries
          .map((e) => e.value.copyWith(orderIndex: e.key))
          .toList(),
    );

    await app.saveRoutine(routine);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingRoutine == null ? 'Nuova scheda' : 'Modifica scheda',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton(
              onPressed: () => _save(app),
              child: const Text('Salva'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome scheda',
              hintText: 'Es. Push A, Full Body, Gambe...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Descrizione (opzionale)',
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Giorni della settimana',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              final day = i + 1;
              final selected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(AnalyticsService.weekdayShortNames[i]),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Esercizi (${_items.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _addExercise(app),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Aggiungi'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Nessun esercizio inserito. Tocca "+ Aggiungi" per comporre la scheda.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final moved = _items.removeAt(oldIdx);
                  _items.insert(newIdx, moved);
                });
              },
              itemBuilder: (_, idx) {
                final item = _items[idx];
                final ex = app.exerciseMap[item.exerciseId];
                return Padding(
                  key: ValueKey('rex_${item.exerciseId}_$idx'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.drag_handle_rounded),
                      title: Text(
                        ex?.name ?? 'Esercizio',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${item.targetSets} serie × ${item.targetReps} rip. • Rec. ${AnalyticsService.formatClock(item.restSeconds)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.tune_rounded),
                            onPressed: () => _editRoutineExercise(idx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () =>
                                setState(() => _items.removeAt(idx)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}