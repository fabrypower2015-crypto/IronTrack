import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'active_workout_screen.dart';
import 'tools_screen.dart';

/// Hub Allenamento: avvio rapido da scheda o sessione libera + Storico completo
/// ricercabile, filtrabile, modificabile, duplicabile ed eliminabile.
class WorkoutHubScreen extends StatefulWidget {
  const WorkoutHubScreen({super.key});

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen> {
  String _searchQuery = '';
  int? _filterRoutineId;
  int? _filterExerciseId;
  DateTimeRange? _filterDateRange;

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _filterDateRange,
    );
    if (picked != null) {
      setState(() => _filterDateRange = picked);
    }
  }

  Future<void> _pickExerciseFilter(AppProvider app) async {
    final chosen = await ExercisePickerSheet.show(
      context,
      exercises: app.exercises,
      title: 'Filtra storico per esercizio',
    );
    if (chosen != null) {
      setState(() => _filterExerciseId = chosen.id);
    }
  }

  Future<void> _startOrResume(AppProvider app, {Routine? routine}) async {
    if (app.activeWorkout == null) {
      await app.startWorkout(routine: routine);
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
  }

  Future<void> _duplicateWorkout(AppProvider app, WorkoutSession past) async {
    if (app.activeWorkout != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hai già una sessione attiva. Terminala o annullala prima di duplicarne un\'altra.',
          ),
        ),
      );
      return;
    }
    await app.duplicatePastWorkoutAsLive(past);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
  }

  Future<void> _confirmDeleteWorkout(AppProvider app, WorkoutSession w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare allenamento?'),
        content: Text(
          'Vuoi rimuovere "${w.name}" del ${formatItalianDate(w.startedAt)} dallo storico?',
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
    if (ok == true && w.id != null) {
      await app.deleteCompletedWorkout(w.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;

    // Applicazione filtri allo storico
    final filteredWorkouts = app.completedWorkouts.where((w) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final inName = w.name.toLowerCase().contains(q);
        final inNotes = w.notes.toLowerCase().contains(q);
        final inEx = w.exercises.any((e) {
          final ex = app.exerciseMap[e.exerciseId];
          return ex != null && ex.name.toLowerCase().contains(q);
        });
        if (!inName && !inNotes && !inEx) return false;
      }
      if (_filterRoutineId != null && w.routineId != _filterRoutineId) {
        return false;
      }
      if (_filterExerciseId != null &&
          !w.exercises.any((e) => e.exerciseId == _filterExerciseId)) {
        return false;
      }
      if (_filterDateRange != null) {
        final d = DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day);
        final start = DateTime(
          _filterDateRange!.start.year,
          _filterDateRange!.start.month,
          _filterDateRange!.start.day,
        );
        final end = DateTime(
          _filterDateRange!.end.year,
          _filterDateRange!.end.month,
          _filterDateRange!.end.day,
        );
        if (d.isBefore(start) || d.isAfter(end)) return false;
      }
      return true;
    }).toList();

    final hasActiveFilters = _filterRoutineId != null ||
        _filterExerciseId != null ||
        _filterDateRange != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allenamento'),
        actions: [
          IconButton(
            tooltip: 'Timer Tabata / EMOM',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ToolsScreen(initialTabIndex: 2),
                ),
              );
            },
            icon: const Icon(Icons.timer_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          app.activeWorkout != null ? 92 : 28,
        ),
        children: [
          // Sezione avvio rapido
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _startOrResume(app),
                  icon: Icon(
                    app.activeWorkout != null
                        ? Icons.play_arrow_rounded
                        : Icons.flash_on_rounded,
                  ),
                  label: Text(
                    app.activeWorkout != null
                        ? 'Riprendi live'
                        : 'Sessione libera',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ToolsScreen(initialTabIndex: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.av_timer_rounded),
                label: const Text('Tabata'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Carosello avvio rapido schede
          SectionHeader(
            title: 'Avvia da scheda',
            actionLabel: 'Gestisci',
            onAction: () => app.setTabIndex(3),
          ),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: app.routines.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, idx) {
                final r = app.routines[idx];
                return SizedBox(
                  width: 210,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _startOrResume(app, routine: r),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: cs.primary,
                                  size: 22,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r.exercises.length} esercizi',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              r.weekdays.isEmpty
                                  ? 'Giorni liberi'
                                  : r.weekdays
                                      .map((d) =>
                                          AnalyticsService.weekdayShortNames[d - 1])
                                      .join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),

          // Intestazione Storico + Ricerca + Filtri
          SectionHeader(
            title: 'Storico allenamenti (${filteredWorkouts.length})',
            actionLabel: hasActiveFilters ? 'Azzera filtri' : null,
            onAction: hasActiveFilters
                ? () => setState(() {
                      _filterRoutineId = null;
                      _filterExerciseId = null;
                      _filterDateRange = null;
                    })
                : null,
          ),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: const InputDecoration(
              hintText: 'Cerca allenamento, esercizio o nota...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),

          // Chip filtri: Data, Scheda, Esercizio
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text(
                    _filterDateRange == null
                        ? 'Data'
                        : '${formatShortDate(_filterDateRange!.start)} - ${formatShortDate(_filterDateRange!.end)}',
                  ),
                  selected: _filterDateRange != null,
                  onSelected: (_) => _pickDateRange(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.fitness_center_rounded, size: 16),
                  label: Text(
                    _filterExerciseId == null
                        ? 'Esercizio'
                        : (app.exerciseMap[_filterExerciseId!]?.name ??
                            'Esercizio'),
                  ),
                  selected: _filterExerciseId != null,
                  onSelected: (_) => _pickExerciseFilter(app),
                ),
                const SizedBox(width: 8),
                ...app.routines.map((r) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(r.name),
                        selected: _filterRoutineId == r.id,
                        onSelected: (sel) => setState(
                          () => _filterRoutineId = sel ? r.id : null,
                        ),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lista allenamenti passati
          if (filteredWorkouts.isEmpty)
            const EmptyStateView(
              icon: Icons.history_rounded,
              title: 'Nessun allenamento trovato',
              subtitle:
                  'Completa una sessione oppure modifica i filtri di ricerca.',
            )
          else
            ...filteredWorkouts.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _PastWorkoutDetailScreen(workout: w),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        w.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatItalianDateTime(w.startedAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (act) {
                                    if (act == 'edit') {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              _PastWorkoutDetailScreen(
                                            workout: w,
                                            startInEditMode: true,
                                          ),
                                        ),
                                      );
                                    } else if (act == 'duplicate') {
                                      _duplicateWorkout(app, w);
                                    } else if (act == 'delete') {
                                      _confirmDeleteWorkout(app, w);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Modifica allenamento'),
                                    ),
                                    PopupMenuItem(
                                      value: 'duplicate',
                                      child: Text('Duplica e riavvia ora'),
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
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                _pill(
                                  Icons.timer_outlined,
                                  AnalyticsService.formatDuration(
                                      w.durationSeconds),
                                ),
                                _pill(
                                  Icons.fitness_center_rounded,
                                  AnalyticsService.formatVolume(
                                      w.totalVolumeKg, unit),
                                ),
                                _pill(
                                  Icons.repeat_rounded,
                                  '${w.totalCompletedSets} serie',
                                ),
                                if (w.prCount > 0)
                                  _pill(
                                    Icons.emoji_events_rounded,
                                    '${w.prCount} PR',
                                    color: const Color(0xFFD97706),
                                  ),
                              ],
                            ),
                            if (w.exercises.isNotEmpty) ...[
                              const Divider(height: 18),
                              ...w.exercises.take(4).map((e) {
                                final exName =
                                    app.exerciseMap[e.exerciseId]?.name ??
                                        'Esercizio';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${e.completedSetsCount}× $exName',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12.5),
                                        ),
                                      ),
                                      Text(
                                        e.maxWeightKg > 0
                                            ? 'Max ${AnalyticsService.formatWeight(e.maxWeightKg, unit)}'
                                            : '-',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (w.exercises.length > 4)
                                Text(
                                  '+ altri ${w.exercises.length - 4} esercizi...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, {Color? color}) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c),
        ),
      ],
    );
  }
}

/// Schermata di dettaglio e modifica completa di un allenamento passato dallo storico.
class _PastWorkoutDetailScreen extends StatefulWidget {
  final WorkoutSession workout;
  final bool startInEditMode;

  const _PastWorkoutDetailScreen({
    required this.workout,
    this.startInEditMode = false,
  });

  @override
  State<_PastWorkoutDetailScreen> createState() =>
      _PastWorkoutDetailScreenState();
}

class _PastWorkoutDetailScreenState extends State<_PastWorkoutDetailScreen> {
  late bool _editing;
  late WorkoutSession _draft;
  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _editing = widget.startInEditMode;
    _draft = widget.workout;
    _nameCtrl = TextEditingController(text: _draft.name);
    _notesCtrl = TextEditingController(text: _draft.notes);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges(AppProvider app) async {
    final updated = _draft.copyWith(
      name: _nameCtrl.text.trim().isEmpty ? _draft.name : _nameCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );
    await app.updateCompletedWorkout(updated);
    if (!mounted) return;
    setState(() {
      _draft = updated;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modifiche salvate nello storico.')),
    );
  }

  Future<void> _editSetDialog(
    int exIdx,
    int setIdx,
    WorkoutSet current,
    String unit,
  ) async {
    final wCtrl = TextEditingController(
      text: AnalyticsService.formatWeight(
        current.weightKg,
        unit,
        includeUnit: false,
      ),
    );
    final rCtrl = TextEditingController(text: current.reps.toString());
    final rpeCtrl = TextEditingController(
      text: current.rpe != null ? current.rpe!.toString() : '',
    );
    SetType type = current.setType;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('Modifica serie ${setIdx + 1}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Peso ($unit)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ripetizioni'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rpeCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'RPE (opzionale)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<SetType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Tipo serie'),
                items: SetType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setModalState(() => type = v);
                },
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
              child: const Text('Aggiorna'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final wVal =
          double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final repsVal = int.tryParse(rCtrl.text) ?? 0;
      final rpeVal = double.tryParse(rpeCtrl.text.replaceAll(',', '.'));

      final exList = [..._draft.exercises];
      final ex = exList[exIdx];
      final sets = [...ex.sets];
      sets[setIdx] = current.copyWith(
        weightKg: AnalyticsService.toStorageKg(wVal, unit),
        reps: repsVal,
        rpe: rpeVal,
        clearRpe: rpeCtrl.text.trim().isEmpty,
        setType: type,
        isCompleted: true,
      );
      exList[exIdx] = ex.copyWith(sets: sets);
      setState(() => _draft = _draft.copyWith(exercises: exList));
    }

    wCtrl.dispose();
    rCtrl.dispose();
    rpeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifica allenamento' : _draft.name),
        actions: [
          if (_editing)
            FilledButton(
              onPressed: () => _saveChanges(app),
              child: const Text('Salva'),
            )
          else
            IconButton(
              tooltip: 'Modifica',
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _editing
                  ? Column(
                      children: [
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome allenamento',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Note',
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatItalianDateTime(_draft.startedAt),
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Durata: ${AnalyticsService.formatDuration(_draft.durationSeconds)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Volume: ${AnalyticsService.formatVolume(_draft.totalVolumeKg, unit)}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        if (_draft.notes.isNotEmpty) ...[
                          const Divider(height: 20),
                          Text(_draft.notes),
                        ],
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          ..._draft.exercises.asMap().entries.map((entry) {
            final exIdx = entry.key;
            final log = entry.value;
            final ex = app.exerciseMap[log.exerciseId];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ex?.name ?? 'Esercizio',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (_editing)
                            IconButton(
                              tooltip: 'Aggiungi serie',
                              onPressed: () {
                                final exList = [..._draft.exercises];
                                final last = log.sets.isNotEmpty
                                    ? log.sets.last
                                    : null;
                                exList[exIdx] = log.copyWith(
                                  sets: [
                                    ...log.sets,
                                    WorkoutSet(
                                      workoutExerciseId: log.id ?? 0,
                                      setNumber: log.sets.length + 1,
                                      weightKg: last?.weightKg ?? 0,
                                      reps: last?.reps ?? 10,
                                      isCompleted: true,
                                    ),
                                  ],
                                );
                                setState(() =>
                                    _draft = _draft.copyWith(exercises: exList));
                              },
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...log.sets.asMap().entries.map((sEntry) {
                        final sIdx = sEntry.key;
                        final s = sEntry.value;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: cs.primary.alphaPct(0.15),
                            child: Text(
                              '${sIdx + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            '${AnalyticsService.formatWeight(s.weightKg, unit)} × ${s.reps} rip. (${s.setType.label})',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '1RM: ${AnalyticsService.formatWeight(s.estimated1RmKg, unit)}${s.rpe != null ? " • RPE ${s.rpe}" : ""}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: _editing
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 19),
                                      onPressed: () =>
                                          _editSetDialog(exIdx, sIdx, s, unit),
                                    ),
                                    if (log.sets.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 19, color: Colors.red),
                                        onPressed: () {
                                          final exList = [..._draft.exercises];
                                          final sets = [...log.sets]
                                            ..removeAt(sIdx);
                                          exList[exIdx] =
                                              log.copyWith(sets: sets);
                                          setState(() => _draft = _draft
                                              .copyWith(exercises: exList));
                                        },
                                      ),
                                  ],
                                )
                              : (s.isPr
                                  ? const Icon(
                                      Icons.emoji_events_rounded,
                                      color: Color(0xFFD97706),
                                      size: 20,
                                    )
                                  : null),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_editing)
            OutlinedButton.icon(
              onPressed: () async {
                final chosen = await ExercisePickerSheet.show(
                  context,
                  exercises: app.exercises,
                  title: 'Aggiungi esercizio',
                );
                if (chosen != null && chosen.id != null) {
                  setState(() {
                    _draft = _draft.copyWith(
                      exercises: [
                        ..._draft.exercises,
                        WorkoutExerciseLog(
                          workoutId: _draft.id ?? 0,
                          exerciseId: chosen.id!,
                          orderIndex: _draft.exercises.length,
                          sets: const [
                            WorkoutSet(
                              workoutExerciseId: 0,
                              setNumber: 1,
                              weightKg: 20,
                              reps: 10,
                              isCompleted: true,
                            ),
                          ],
                        ),
                      ],
                    );
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi esercizio alla sessione'),
            ),
        ],
      ),
    );
  }
}