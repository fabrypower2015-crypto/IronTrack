import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'tools_screen.dart';

/// Schermata della sessione di allenamento live con autosalvataggio SQLite,
/// cronometro, timer recupero automatico e notifica PR in tempo reale.
class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  /// Apre il selettore esercizi per aggiungere un esercizio durante la sessione.
  Future<void> _addExercise(BuildContext context, AppProvider app) async {
    final chosen = await ExercisePickerSheet.show(
      context,
      exercises: app.exercises,
      title: 'Aggiungi esercizio alla sessione',
    );
    if (chosen != null && chosen.id != null) {
      await app.addExerciseToActiveWorkout(chosen.id!);
    }
  }

  /// Modifica titolo e note generali della sessione in corso.
  Future<void> _editWorkoutMeta(BuildContext context, AppProvider app) async {
    final workout = app.activeWorkout;
    if (workout == null) return;

    final nameCtrl = TextEditingController(text: workout.name);
    final notesCtrl = TextEditingController(text: workout.notes);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dettagli sessione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nome allenamento'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note allenamento',
                hintText: 'Es. Ottime sensazioni, recupero rapido...',
              ),
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
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await app.updateActiveWorkoutMeta(
        name: nameCtrl.text.trim().isEmpty ? workout.name : nameCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
      );
    }

    nameCtrl.dispose();
    notesCtrl.dispose();
  }

  /// Finestra di riordino rapido degli esercizi tramite drag-and-drop.
  Future<void> _showReorderDialog(BuildContext context, AppProvider app) async {
    final workout = app.activeWorkout;
    if (workout == null || workout.exercises.length < 2) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer<AppProvider>(
        builder: (_, provider, __) {
          final current = provider.activeWorkout;
          if (current == null) return const SizedBox.shrink();
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    'Trascina per riordinare gli esercizi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Flexible(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    itemCount: current.exercises.length,
                    onReorder: (oldIdx, newIdx) {
                      provider.reorderActiveExercises(oldIdx, newIdx);
                    },
                    itemBuilder: (_, idx) {
                      final log = current.exercises[idx];
                      final ex = provider.exerciseMap[log.exerciseId];
                      return ListTile(
                        key: ValueKey('reorder_${log.id ?? idx}_${log.exerciseId}'),
                        leading: const Icon(Icons.drag_handle_rounded),
                        title: Text(
                          ex?.name ?? 'Esercizio',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${log.sets.length} serie'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Imposta la durata personalizzata del recupero per uno specifico esercizio.
  Future<void> _editRestDuration(
    BuildContext context,
    AppProvider app,
    int exerciseIndex,
    int currentSeconds,
  ) async {
    int selected = currentSeconds;
    const presets = [30, 45, 60, 75, 90, 120, 150, 180, 240];

    final confirmed = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Timer recupero esercizio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AnalyticsService.formatClock(selected),
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((sec) {
                  return ChoiceChip(
                    label: Text(AnalyticsService.formatClock(sec)),
                    selected: selected == sec,
                    onSelected: (_) => setModalState(() => selected = sec),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Applica'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != null) {
      await app.updateActiveExerciseMeta(exerciseIndex, restSeconds: confirmed);
    }
  }

  /// Modifica le note tecniche di un singolo esercizio durante la sessione.
  Future<void> _editExerciseNotes(
    BuildContext context,
    AppProvider app,
    int exerciseIndex,
    String currentNotes,
  ) async {
    final ctrl = TextEditingController(text: currentNotes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note esercizio'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Es. Sedile foro 4, fermo 1s al petto...',
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
    );

    if (ok == true) {
      await app.updateActiveExerciseMeta(
        exerciseIndex,
        notes: ctrl.text.trim(),
      );
    }
    ctrl.dispose();
  }

  /// Chiede il carico allenante target e inserisce la rampa di riscaldamento automatica.
  Future<void> _insertWarmupRamp(
    BuildContext context,
    AppProvider app,
    int exerciseIndex,
    WorkoutExerciseLog log,
  ) async {
    final unit = app.profile.unit;
    final defaultKg = log.sets.isNotEmpty && log.sets.first.weightKg > 0
        ? log.sets.first.weightKg
        : 60.0;
    final ctrl = TextEditingController(
      text: AnalyticsService.formatWeight(defaultKg, unit, includeUnit: false),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Genera serie di riscaldamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inserisci il carico allenante target: verranno aggiunte 3 serie progressive (50%×8, 70%×5, 85%×2).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Carico target ($unit)'),
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
            child: const Text('Aggiungi rampa'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final parsed = double.tryParse(ctrl.text.replaceAll(',', '.'));
      if (parsed != null && parsed > 0) {
        final kg = AnalyticsService.toStorageKg(parsed, unit);
        await app.insertWarmupRampForExercise(exerciseIndex, kg);
      }
    }
    ctrl.dispose();
  }

  /// Conferma e conclude l'allenamento salvandolo definitivamente nello storico.
  Future<void> _confirmFinish(BuildContext context, AppProvider app) async {
    final workout = app.activeWorkout;
    if (workout == null) return;

    final completedSets = workout.totalCompletedSets;
    final unit = app.profile.unit;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminare allenamento?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Durata: ${AnalyticsService.formatClock(app.activeElapsedSeconds)}'),
            Text('Serie completate: $completedSets'),
            Text(
              'Volume totale: ${AnalyticsService.formatVolume(workout.totalVolumeKg, unit)}',
            ),
            if (workout.prCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Nuovi Record Personali (PR): ${workout.prCount}!',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            if (completedSets == 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Attenzione: non hai ancora spuntato nessuna serie come completata.',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continua'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salva e concludi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await app.finishActiveWorkout();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Allenamento salvato nello storico! Ottimo lavoro.'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  /// Conferma l'annullamento della sessione senza salvare.
  Future<void> _confirmDiscard(BuildContext context, AppProvider app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annullare la sessione?'),
        content: const Text(
          'Tutti i dati inseriti in questa sessione verranno eliminati definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Indietro'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina sessione'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await app.discardActiveWorkout();
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final workout = app.activeWorkout;
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;

    if (workout == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sessione live')),
        body: EmptyStateView(
          icon: Icons.fitness_center_rounded,
          title: 'Nessuna sessione attiva',
          subtitle: 'Avvia un nuovo allenamento dalla Home o dalle Schede.',
          buttonLabel: 'Torna indietro',
          onPressed: () => Navigator.pop(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Riduci a icona (sessione salvata)',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
        ),
        title: InkWell(
          onTap: () => _editWorkoutMeta(context, app),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workout.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 13, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    AnalyticsService.formatClock(app.activeElapsedSeconds),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '• ${AnalyticsService.formatVolume(workout.totalVolumeKg, unit)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Calcolatore dischi',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ToolsScreen(initialTabIndex: 0),
                ),
              );
            },
            icon: const Icon(Icons.calculate_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'meta':
                  _editWorkoutMeta(context, app);
                  break;
                case 'reorder':
                  _showReorderDialog(context, app);
                  break;
                case 'discard':
                  _confirmDiscard(context, app);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'meta',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_note_rounded),
                  title: Text('Nome e note sessione'),
                ),
              ),
              const PopupMenuItem(
                value: 'reorder',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.swap_vert_rounded),
                  title: Text('Riordina esercizi'),
                ),
              ),
              const PopupMenuItem(
                value: 'discard',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: Text(
                    'Annulla allenamento',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton(
              onPressed: () => _confirmFinish(context, app),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Fine'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra del timer di recupero automatico quando attivo
          if (app.restRunning) _buildRestTimerBanner(context, app, cs),

          // Riepilogo compatto live + indicatore autosalvataggio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cs.surfaceContainerHighest.alphaPct(0.35),
            child: Row(
              children: [
                Icon(Icons.cloud_done_outlined, size: 15, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Salvataggio automatico attivo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${workout.totalCompletedSets} serie',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                if (workout.prCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).alphaPct(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${workout.prCount} PR',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Lista degli esercizi nella sessione
          Expanded(
            child: workout.exercises.isEmpty
                ? EmptyStateView(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Sessione pronta!',
                    subtitle:
                        'Aggiungi il primo esercizio dalla libreria per iniziare a registrare le serie.',
                    buttonLabel: 'Aggiungi esercizio',
                    onPressed: () => _addExercise(context, app),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                    itemCount: workout.exercises.length + 1,
                    itemBuilder: (context, index) {
                      if (index == workout.exercises.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: OutlinedButton.icon(
                            onPressed: () => _addExercise(context, app),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Aggiungi esercizio'),
                          ),
                        );
                      }

                      final log = workout.exercises[index];
                      final exercise = app.exerciseMap[log.exerciseId];
                      final prevSets =
                          app.getPreviousSetsForExercise(log.exerciseId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _ExerciseSessionCard(
                          exerciseIndex: index,
                          log: log,
                          exercise: exercise,
                          previousSets: prevSets,
                          unit: unit,
                          onEditRest: () => _editRestDuration(
                            context,
                            app,
                            index,
                            log.restSeconds,
                          ),
                          onEditNotes: () =>
                              _editExerciseNotes(context, app, index, log.notes),
                          onInsertWarmup: () =>
                              _insertWarmupRamp(context, app, index, log),
                          onMoveUp: index > 0
                              ? () => app.reorderActiveExercises(index, index - 1)
                              : null,
                          onMoveDown: index < workout.exercises.length - 1
                              ? () => app.reorderActiveExercises(index, index + 2)
                              : null,
                          onRemoveExercise: () =>
                              app.removeExerciseFromActiveWorkout(index),
                          onAddSet: () => app.addSetToActiveExercise(index),
                          onRemoveSet: (sIdx) =>
                              app.removeSetFromActiveExercise(index, sIdx),
                          onUpdateSet: (sIdx, updated) async {
                            final hitPr = await app.updateSetInActiveWorkout(
                              index,
                              sIdx,
                              updated,
                            );
                            if (hitPr && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFFD97706),
                                  behavior: SnackBarBehavior.floating,
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.emoji_events_rounded,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'NUOVO RECORD su ${exercise?.name ?? "esercizio"}! ${AnalyticsService.formatWeight(updated.weightKg, unit)} × ${updated.reps}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Banner interattivo del timer di recupero tra le serie.
  Widget _buildRestTimerBanner(
    BuildContext context,
    AppProvider app,
    ColorScheme cs,
  ) {
    final progress = app.restTotalSeconds > 0
        ? (app.restRemainingSeconds / app.restTotalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border(
          bottom: BorderSide(color: cs.primary.alphaPct(0.3)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_bottom_rounded, color: cs.onPrimaryContainer),
              const SizedBox(width: 10),
              Text(
                'Recupero: ${AnalyticsService.formatClock(app.restRemainingSeconds)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => app.adjustRestTimer(-15),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('-15s'),
              ),
              TextButton(
                onPressed: () => app.adjustRestTimer(15),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('+15s'),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Salta recupero',
                onPressed: app.stopRestTimer,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card di un singolo esercizio all'interno della sessione live.
class _ExerciseSessionCard extends StatelessWidget {
  final int exerciseIndex;
  final WorkoutExerciseLog log;
  final Exercise? exercise;
  final List<WorkoutSet> previousSets;
  final String unit;
  final VoidCallback onEditRest;
  final VoidCallback onEditNotes;
  final VoidCallback onInsertWarmup;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onRemoveExercise;
  final VoidCallback onAddSet;
  final void Function(int setIndex) onRemoveSet;
  final Future<void> Function(int setIndex, WorkoutSet updated) onUpdateSet;

  const _ExerciseSessionCard({
    required this.exerciseIndex,
    required this.log,
    required this.exercise,
    required this.previousSets,
    required this.unit,
    required this.onEditRest,
    required this.onEditNotes,
    required this.onInsertWarmup,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemoveExercise,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onUpdateSet,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groupColor = muscleGroupColor(exercise?.muscleGroup ?? '');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intestazione esercizio + menu contestuale
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: groupColor.alphaPct(0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    muscleGroupIcon(exercise?.muscleGroup ?? ''),
                    color: groupColor,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise?.name ?? 'Esercizio',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '${exercise?.muscleGroup ?? ''} • ',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          InkWell(
                            onTap: onEditRest,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 13, color: cs.primary),
                                const SizedBox(width: 3),
                                Text(
                                  'Rec. ${AnalyticsService.formatClock(log.restSeconds)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    switch (val) {
                      case 'rest':
                        onEditRest();
                        break;
                      case 'notes':
                        onEditNotes();
                        break;
                      case 'warmup':
                        onInsertWarmup();
                        break;
                      case 'up':
                        onMoveUp?.call();
                        break;
                      case 'down':
                        onMoveDown?.call();
                        break;
                      case 'delete':
                        onRemoveExercise();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'rest',
                      child: Text('Cambia timer recupero'),
                    ),
                    const PopupMenuItem(
                      value: 'notes',
                      child: Text('Aggiungi / modifica note'),
                    ),
                    const PopupMenuItem(
                      value: 'warmup',
                      child: Text('Inserisci rampa riscaldamento'),
                    ),
                    if (onMoveUp != null)
                      const PopupMenuItem(
                        value: 'up',
                        child: Text('Sposta su'),
                      ),
                    if (onMoveDown != null)
                      const PopupMenuItem(
                        value: 'down',
                        child: Text('Sposta giù'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Rimuovi esercizio',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Note esercizio se presenti
            if (log.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: onEditNotes,
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.alphaPct(0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      log.notes,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // Intestazione colonne tabella serie
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 44,
                    child: Text(
                      'SERIE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'ULTIMA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      unit.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'RIP.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const SizedBox(
                    width: 46,
                    child: Text(
                      'RPE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // Righe delle singole serie
            ...log.sets.asMap().entries.map((entry) {
              final sIdx = entry.key;
              final setItem = entry.value;
              final prev =
                  sIdx < previousSets.length ? previousSets[sIdx] : null;
              return _SetRowWidget(
                key: ValueKey('set_${log.id ?? exerciseIndex}_${setItem.id ?? sIdx}_$sIdx'),
                setItem: setItem,
                previousSet: prev,
                unit: unit,
                onChanged: (updated) => onUpdateSet(sIdx, updated),
                onDelete: log.sets.length > 1 ? () => onRemoveSet(sIdx) : null,
              );
            }),

            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onAddSet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Aggiungi serie'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga editabile per una singola serie (tipo, riferimento precedente, peso, rip, RPE, completata + PR).
class _SetRowWidget extends StatefulWidget {
  final WorkoutSet setItem;
  final WorkoutSet? previousSet;
  final String unit;
  final Future<void> Function(WorkoutSet updated) onChanged;
  final VoidCallback? onDelete;

  const _SetRowWidget({
    super.key,
    required this.setItem,
    required this.previousSet,
    required this.unit,
    required this.onChanged,
    this.onDelete,
  });

  @override
  State<_SetRowWidget> createState() => _SetRowWidgetState();
}

class _SetRowWidgetState extends State<_SetRowWidget> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;
  late TextEditingController _rpeCtrl;
  final FocusNode _weightFocus = FocusNode();
  final FocusNode _repsFocus = FocusNode();
  final FocusNode _rpeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(text: _formatInitialWeight());
    _repsCtrl = TextEditingController(
      text: widget.setItem.reps > 0 ? widget.setItem.reps.toString() : '',
    );
    _rpeCtrl = TextEditingController(
      text: widget.setItem.rpe != null
          ? widget.setItem.rpe!.toStringAsFixed(
              widget.setItem.rpe! % 1 == 0 ? 0 : 1,
            )
          : '',
    );
  }

  String _formatInitialWeight() {
    if (widget.setItem.weightKg <= 0) return '';
    return AnalyticsService.formatWeight(
      widget.setItem.weightKg,
      widget.unit,
      includeUnit: false,
    );
  }

  @override
  void didUpdateWidget(covariant _SetRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincronizza solo se il campo non è in digitazione attiva
    if (!_weightFocus.hasFocus &&
        oldWidget.setItem.weightKg != widget.setItem.weightKg) {
      _weightCtrl.text = _formatInitialWeight();
    }
    if (!_repsFocus.hasFocus && oldWidget.setItem.reps != widget.setItem.reps) {
      _repsCtrl.text =
          widget.setItem.reps > 0 ? widget.setItem.reps.toString() : '';
    }
    if (!_rpeFocus.hasFocus && oldWidget.setItem.rpe != widget.setItem.rpe) {
      _rpeCtrl.text = widget.setItem.rpe != null
          ? widget.setItem.rpe!.toStringAsFixed(
              widget.setItem.rpe! % 1 == 0 ? 0 : 1,
            )
          : '';
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _rpeCtrl.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    _rpeFocus.dispose();
    super.dispose();
  }

  WorkoutSet _buildCurrentSet({bool? isCompleted, SetType? setType}) {
    final parsedW =
        double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final parsedReps = int.tryParse(_repsCtrl.text.trim()) ?? 0;
    final rawRpe = _rpeCtrl.text.trim().replaceAll(',', '.');
    final parsedRpe = rawRpe.isEmpty ? null : double.tryParse(rawRpe);

    return widget.setItem.copyWith(
      weightKg: AnalyticsService.toStorageKg(parsedW, widget.unit),
      reps: parsedReps,
      rpe: parsedRpe?.clamp(1.0, 10.0),
      clearRpe: rawRpe.isEmpty,
      isCompleted: isCompleted ?? widget.setItem.isCompleted,
      setType: setType ?? widget.setItem.setType,
    );
  }

  Future<void> _selectSetType() async {
    final chosen = await showModalBottomSheet<SetType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Tipo di serie',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            ...SetType.values.map((t) => ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 14,
                    color: _typeColor(t, Theme.of(context).colorScheme),
                  ),
                  title: Text(t.label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: widget.setItem.setType == t
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(ctx, t),
                )),
            if (widget.onDelete != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Elimina questa serie',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDelete!();
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (chosen != null) {
      await widget.onChanged(_buildCurrentSet(setType: chosen));
    }
  }

  Color _typeColor(SetType type, ColorScheme cs) {
    switch (type) {
      case SetType.warmup:
        return const Color(0xFFF59E0B);
      case SetType.dropSet:
        return const Color(0xFF8B5CF6);
      case SetType.failure:
        return const Color(0xFFEF4444);
      case SetType.normal:
        return cs.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = widget.setItem.isCompleted;
    final typeColor = _typeColor(widget.setItem.setType, cs);

    final prevText = widget.previousSet != null
        ? '${AnalyticsService.formatWeight(widget.previousSet!.weightKg, widget.unit, includeUnit: false)}×${widget.previousSet!.reps}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFF10B981).alphaPct(0.11)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Badge numero / tipo serie (toccabile per cambiare tipo o eliminare)
          InkWell(
            onTap: _selectSetType,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 42,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: typeColor.alphaPct(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.setItem.setType == SetType.normal
                        ? '${widget.setItem.setNumber}'
                        : widget.setItem.setType.shortLabel,
                    style: TextStyle(
                      fontSize:
                          widget.setItem.setType == SetType.normal ? 13 : 10,
                      fontWeight: FontWeight.w900,
                      color: typeColor,
                    ),
                  ),
                  if (widget.setItem.isPr && completed)
                    const Text(
                      'PR',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD97706),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Riferimento ultima volta (toccabile per ricopiare i valori)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: widget.previousSet == null
                  ? null
                  : () {
                      final ref = widget.previousSet!;
                      _weightCtrl.text = AnalyticsService.formatWeight(
                        ref.weightKg,
                        widget.unit,
                        includeUnit: false,
                      );
                      _repsCtrl.text = ref.reps.toString();
                      widget.onChanged(_buildCurrentSet());
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  prevText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Campo Peso
          Expanded(
            flex: 2,
            child: _compactInput(
              controller: _weightCtrl,
              focusNode: _weightFocus,
              hint: '0',
              decimal: true,
              onCommit: () => widget.onChanged(_buildCurrentSet()),
            ),
          ),
          const SizedBox(width: 6),

          // Campo Ripetizioni
          Expanded(
            flex: 2,
            child: _compactInput(
              controller: _repsCtrl,
              focusNode: _repsFocus,
              hint: '0',
              decimal: false,
              onCommit: () => widget.onChanged(_buildCurrentSet()),
            ),
          ),
          const SizedBox(width: 6),

          // Campo RPE opzionale
          SizedBox(
            width: 46,
            child: _compactInput(
              controller: _rpeCtrl,
              focusNode: _rpeFocus,
              hint: '-',
              decimal: true,
              onCommit: () => widget.onChanged(_buildCurrentSet()),
            ),
          ),

          // Spunta completamento serie
          SizedBox(
            width: 44,
            child: IconButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                widget.onChanged(_buildCurrentSet(isCompleted: !completed));
              },
              icon: Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: completed ? const Color(0xFF10B981) : cs.outline,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool decimal,
    required VoidCallback onCommit,
  }) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
        onEditingComplete: () {
          focusNode.unfocus();
          onCommit();
        },
        onTapOutside: (_) {
          if (focusNode.hasFocus) {
            focusNode.unfocus();
            onCommit();
          }
        },
      ),
    );
  }
}