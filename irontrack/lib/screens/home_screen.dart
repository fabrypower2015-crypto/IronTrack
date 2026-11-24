import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'active_workout_screen.dart';
import 'tools_screen.dart';

/// Home panoramica: riepilogo a colpo d'occhio di tutti i progressi.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _heatmapMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buongiorno';
    if (h < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  /// Apre il foglio rapido per scegliere se partire dalla scheda consigliata,
  /// da un'altra scheda o da una sessione libera.
  Future<void> _showQuickStartSheet(BuildContext context, AppProvider app) async {
    if (app.activeWorkout != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inizia allenamento',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.alphaPct(0.15),
                    child: Icon(
                      Icons.flash_on_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Sessione libera (da zero)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Aggiungi gli esercizi durante la seduta'),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await app.startWorkout();
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ActiveWorkoutScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Text(
                    'Oppure avvia una scheda',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: app.routines.length,
                    itemBuilder: (_, idx) {
                      final r = app.routines[idx];
                      return ListTile(
                        leading: const Icon(Icons.assignment_outlined),
                        title: Text(
                          r.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${r.exercises.length} esercizi'),
                        trailing: const Icon(Icons.play_arrow_rounded),
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          await app.startWorkout(routine: r);
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ActiveWorkoutScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Finestra rapida per registrare subito il peso corporeo dalla Home.
  Future<void> _showQuickWeightDialog(BuildContext context, AppProvider app) async {
    final unit = app.profile.unit;
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registra peso corporeo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Peso attuale ($unit)',
            hintText: unit == 'kg' ? 'Es. 74.5' : 'Es. 164.0',
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

    if (saved == true) {
      final raw = double.tryParse(controller.text.replaceAll(',', '.'));
      if (raw != null && raw > 0) {
        final weightKg = AnalyticsService.toStorageKg(raw, unit);
        await app.saveBodyMeasurement(
          BodyMeasurement(date: DateTime.now(), weightKg: weightKg),
        );
      }
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;

    final now = DateTime.now();
    final thisWeekWorkouts = AnalyticsService.workoutsInWeek(
      app.completedWorkouts,
      AnalyticsService.startOfWeek(now),
    );
    final weeklyGoal = app.profile.weeklyGoal < 1 ? 1 : app.profile.weeklyGoal;
    final weeklyProgress = (thisWeekWorkouts.length / weeklyGoal).clamp(0.0, 1.0);

    final streaks = AnalyticsService.calculateStreaks(app.completedWorkouts);
    final weeklyVol =
        AnalyticsService.weeklyVolumeComparison(app.completedWorkouts);
    final recommended = app.recommendedRoutine;
    final lastWorkout =
        app.completedWorkouts.isNotEmpty ? app.completedWorkouts.first : null;
    final recentPrs = AnalyticsService.calculatePersonalRecords(
      app.completedWorkouts,
      app.exerciseMap,
    ).take(6).toList();

    final weightEntries = app.measurements
        .where((m) => m.weightKg != null)
        .toList()
        .reversed
        .toList();
    final recentWeights = weightEntries.length > 10
        ? weightEntries.sublist(weightEntries.length - 10)
        : weightEntries;

    final heatmapData = AnalyticsService.monthlyHeatmap(
      app.completedWorkouts,
      _heatmapMonth.year,
      _heatmapMonth.month,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_greeting()}, ${app.profile.name}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(
              DateFormat('EEEE d MMMM', 'it_IT').format(now),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Strumenti palestra',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ToolsScreen()),
              );
            },
            icon: const Icon(Icons.calculate_outlined),
          ),
          const SizedBox(width: 4),
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
          // 1. PULSANTE GRANDE "INIZIA ALLENAMENTO" SEMPRE BEN VISIBILE
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showQuickStartSheet(context, app),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: Icon(
                app.activeWorkout != null
                    ? Icons.play_circle_filled_rounded
                    : Icons.add_circle_rounded,
                size: 24,
              ),
              label: Text(
                app.activeWorkout != null
                    ? 'Riprendi allenamento (${AnalyticsService.formatClock(app.activeElapsedSeconds)})'
                    : 'Inizia allenamento',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. PROSSIMO ALLENAMENTO CONSIGLIATO (IN BASE ALLA SCHEDA)
          if (recommended != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.primary.alphaPct(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.event_available_rounded,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROSSIMO CONSIGLIATO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            recommended.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${recommended.exercises.length} esercizi programmati',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () async {
                        if (app.activeWorkout == null) {
                          await app.startWorkout(routine: recommended);
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ActiveWorkoutScreen(),
                          ),
                        );
                      },
                      child: const Text('Avvia'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),

          // 3. ANELLO OBIETTIVO SETTIMANALE + STREAK
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 58,
                                height: 58,
                                child: CircularProgressIndicator(
                                  value: weeklyProgress,
                                  strokeWidth: 7,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor:
                                      cs.surfaceContainerHighest,
                                ),
                              ),
                              Text(
                                '${thisWeekWorkouts.length}/$weeklyGoal',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Settimana',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                thisWeekWorkouts.length >= weeklyGoal
                                    ? 'Obiettivo centrato!'
                                    : 'Mancano ${weeklyGoal - thisWeekWorkouts.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).alphaPct(0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Color(0xFFF59E0B),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${streaks.weekStreak} sett.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                'Streak (${streaks.dayStreak}g)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. VOLUME SETTIMANALE QUESTA SETTIMANA VS SCORSA
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Volume settimanale',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      DeltaBadge(percent: weeklyVol.deltaPct),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AnalyticsService.formatVolume(weeklyVol.currentKg, unit),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          'vs ${AnalyticsService.formatVolume(weeklyVol.previousKg, unit)} sett. scorsa',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: weeklyVol.previousKg > 0
                          ? (weeklyVol.currentKg / weeklyVol.previousKg)
                              .clamp(0.0, 1.0)
                          : (weeklyVol.currentKg > 0 ? 1.0 : 0.0),
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 5. ULTIMO ALLENAMENTO CON RIEPILOGO RAPIDO
          SectionHeader(
            title: 'Ultimo allenamento',
            actionLabel: 'Storico',
            onAction: () => app.setTabIndex(1),
          ),
          if (lastWorkout == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Nessun allenamento ancora completato. Premi "Inizia allenamento" per registrare la tua prima sessione!',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => app.setTabIndex(1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastWorkout.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            formatShortDate(lastWorkout.startedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _miniStat(
                            Icons.timer_outlined,
                            AnalyticsService.formatDuration(
                                lastWorkout.durationSeconds),
                            'Durata',
                          ),
                          _miniStat(
                            Icons.fitness_center_rounded,
                            AnalyticsService.formatVolume(
                                lastWorkout.totalVolumeKg, unit),
                            'Volume',
                          ),
                          _miniStat(
                            Icons.repeat_rounded,
                            '${lastWorkout.totalCompletedSets}',
                            'Serie',
                          ),
                          _miniStat(
                            Icons.emoji_events_rounded,
                            '${lastWorkout.prCount}',
                            'Record',
                            highlight: lastWorkout.prCount > 0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),

          // 6. RECORD PERSONALI RECENTI (PR) CON BADGE
          SectionHeader(
            title: 'Record personali recenti',
            actionLabel: 'Tutti i PR',
            onAction: () => app.setTabIndex(2),
          ),
          if (recentPrs.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'I tuoi PR appariranno qui automaticamente non appena completerai le prime serie.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            SizedBox(
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentPrs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final pr = recentPrs[index];
                  return SizedBox(
                    width: 195,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        const Color(0xFFD97706).alphaPct(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.emoji_events_rounded,
                                        size: 13,
                                        color: Color(0xFFD97706),
                                      ),
                                      SizedBox(width: 3),
                                      Text(
                                        'PR',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  formatShortDate(pr.date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pr.exerciseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${AnalyticsService.formatWeight(pr.maxWeightKg, unit)} × ${pr.repsAtMaxWeight}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: cs.primary,
                              ),
                            ),
                            Text(
                              '1RM: ${AnalyticsService.formatWeight(pr.best1RmKg, unit)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 18),

          // 7. MINI-GRAFICO DEL PESO CORPOREO
          SectionHeader(
            title: 'Peso corporeo',
            actionLabel: '+ Registra',
            onAction: () => _showQuickWeightDialog(context, app),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: recentWeights.isEmpty
                  ? Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Nessuna pesata salvata. Tocca "+ Registra" per tracciare il peso.',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => _showQuickWeightDialog(context, app),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              AnalyticsService.formatWeight(
                                recentWeights.last.weightKg!,
                                unit,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 10),
                            if (recentWeights.length >= 2)
                              DeltaBadge(
                                percent: AnalyticsService.percentChange(
                                  recentWeights[recentWeights.length - 2]
                                      .weightKg!,
                                  recentWeights.last.weightKg!,
                                ),
                              ),
                            const Spacer(),
                            Text(
                              formatShortDate(recentWeights.last.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 110,
                          child: _buildMiniWeightChart(recentWeights, unit, cs),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // 8. CALENDARIO A HEATMAP DEGLI ALLENAMENTI DEL MESE
          const SectionHeader(title: 'Calendario allenamenti'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMonthlyHeatmap(context, heatmapData, cs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
    IconData icon,
    String value,
    String label, {
    bool highlight = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: highlight ? const Color(0xFFD97706) : cs.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildMiniWeightChart(
    List<BodyMeasurement> entries,
    String unit,
    ColorScheme cs,
  ) {
    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < entries.length; i++) {
      final y = AnalyticsService.displayWeight(entries[i].weightKg!, unit);
      spots.add(FlSpot(i.toDouble(), y));
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final padding = (maxY - minY).abs() < 1.0 ? 2.0 : (maxY - minY) * 0.2;

    return LineChart(
      LineChartData(
        minY: (minY - padding).clamp(0, double.infinity),
        maxY: maxY + padding,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItems: (touched) => touched.map((s) {
              final idx = s.x.round().clamp(0, entries.length - 1);
              return LineTooltipItem(
                '${s.y.toStringAsFixed(1)} $unit\n${formatShortDate(entries[idx].date)}',
                TextStyle(
                  color: cs.onInverseSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: cs.primary,
            barWidth: 3,
            dotData: FlDotData(show: spots.length <= 12),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.alphaPct(0.14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyHeatmap(
    BuildContext context,
    Map<DateTime, int> counts,
    ColorScheme cs,
  ) {
    final firstDay = DateTime(_heatmapMonth.year, _heatmapMonth.month, 1);
    final daysInMonth =
        DateTime(_heatmapMonth.year, _heatmapMonth.month + 1, 0).day;
    final leadingEmpty = firstDay.weekday - 1; // 0 = Lun
    final totalCells = leadingEmpty + daysInMonth;
    final today = DateTime.now();

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _heatmapMonth =
                      DateTime(_heatmapMonth.year, _heatmapMonth.month - 1, 1);
                });
              },
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy', 'it_IT')
                    .format(_heatmapMonth)
                    .toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _heatmapMonth =
                      DateTime(_heatmapMonth.year, _heatmapMonth.month + 1, 1);
                });
              },
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: AnalyticsService.weekdayShortNames
              .map(
                (d) => Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            if (index < leadingEmpty) {
              return const SizedBox.shrink();
            }
            final dayNum = index - leadingEmpty + 1;
            final date =
                DateTime(_heatmapMonth.year, _heatmapMonth.month, dayNum);
            final workoutsCount = counts[date] ?? 0;
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;

            Color bg;
            Color textColor;
            if (workoutsCount >= 2) {
              bg = cs.primary;
              textColor = Colors.white;
            } else if (workoutsCount == 1) {
              bg = cs.primary.alphaPct(0.68);
              textColor = Colors.white;
            } else {
              bg = cs.surfaceContainerHighest.alphaPct(0.5);
              textColor = cs.onSurfaceVariant;
            }

            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(9),
                border: isToday
                    ? Border.all(color: cs.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        workoutsCount > 0 || isToday ? FontWeight.w800 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Riposo',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 6),
            _legendBox(cs.surfaceContainerHighest.alphaPct(0.5)),
            const SizedBox(width: 4),
            _legendBox(cs.primary.alphaPct(0.68)),
            const SizedBox(width: 4),
            _legendBox(cs.primary),
            const SizedBox(width: 6),
            Text(
              '2+ sessioni',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}