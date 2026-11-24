import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Schermata Progressi divisa in 5 sotto-schede:
/// 1) Grafici  2) Tabelle  3) Confronti  4) Corpo & Foto  5) Statistiche
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stato condiviso per i filtri dei grafici
  TimeRangeFilter _range = TimeRangeFilter.months3;
  int? _selectedExerciseId;
  String _exerciseMetric = '1rm'; // 'maxWeight', '1rm', 'volume', 'reps'
  bool _showTrendLine = true;
  bool _muscleRadarMode = false;
  bool _frequencyByMonth = false;
  String _bodyMetricKey = 'weight';

  // Stato per la scheda Tabelle
  int? _tableExerciseId;
  String _tableSortBy = 'date'; // 'date', 'weight', 'volume', '1rm'
  bool _tableDescending = true;
  String _tableGrouping = 'session'; // 'session', 'week', 'month'

  // Stato per la scheda Confronti
  int? _compareExSelfId;
  bool _compareMuscleMode = false;
  int? _compareExAId;
  int? _compareExBId;
  String _compareMuscleA = MuscleGroups.petto;
  String _compareMuscleB = MuscleGroups.schiena;

  // Stato per il confronto Foto prima/dopo
  int? _beforePhotoId;
  int? _afterPhotoId;

  static const Map<String, ({String label, String unit})> _bodyMetrics = {
    'weight': (label: 'Peso corporeo', unit: 'peso'),
    'bodyFat': (label: 'Massa grassa', unit: '%'),
    'chest': (label: 'Petto', unit: 'cm'),
    'waist': (label: 'Vita', unit: 'cm'),
    'hips': (label: 'Fianchi', unit: 'cm'),
    'rightArm': (label: 'Braccio dx', unit: 'cm'),
    'leftArm': (label: 'Braccio sx', unit: 'cm'),
    'rightThigh': (label: 'Coscia dx', unit: 'cm'),
    'leftThigh': (label: 'Coscia sx', unit: 'cm'),
    'calves': (label: 'Polpacci', unit: 'cm'),
    'shoulders': (label: 'Spalle', unit: 'cm'),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Restituisce l'ID del primo esercizio con dati storici (o del primo della libreria).
  int? _resolveDefaultExerciseId(AppProvider app, int? current) {
    if (current != null && app.exerciseMap.containsKey(current)) {
      return current;
    }
    for (final w in app.completedWorkouts) {
      if (w.exercises.isNotEmpty) {
        return w.exercises.first.exerciseId;
      }
    }
    return app.exercises.isNotEmpty ? app.exercises.first.id : null;
  }

  /// Apre il selettore esercizi per aggiornare un filtro.
  Future<void> _pickExercise(
    AppProvider app,
    void Function(int id) onSelected, {
    String title = 'Seleziona esercizio',
  }) async {
    final ex = await ExercisePickerSheet.show(
      context,
      exercises: app.exercises,
      title: title,
    );
    if (ex != null && ex.id != null) {
      setState(() => onSelected(ex.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progressi'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Grafici'),
            Tab(text: 'Tabelle'),
            Tab(text: 'Confronti'),
            Tab(text: 'Corpo & Foto'),
            Tab(text: 'Statistiche'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChartsTab(app),
          _buildTablesTab(app),
          _buildComparisonsTab(app),
          _buildBodyAndPhotosTab(app),
          _buildStatsTab(app),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: GRAFICI (fl_chart con linea di tendenza, tooltip, zoom, barre/radar)
  // ===========================================================================

  Widget _buildChartsTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;
    final exId = _resolveDefaultExerciseId(app, _selectedExerciseId);
    final selectedEx = exId != null ? app.exerciseMap[exId] : null;

    final exPoints = exId != null
        ? AnalyticsService.getExerciseHistory(
            exerciseId: exId,
            workouts: app.completedWorkouts,
            range: _range,
          )
        : <ExerciseSessionPoint>[];

    final muscleVolumes = AnalyticsService.volumeByMuscleGroup(
      workouts: app.completedWorkouts,
      exerciseMap: app.exerciseMap,
      range: _range,
    );

    final freqSeries = AnalyticsService.workoutFrequencySeries(
      workouts: app.completedWorkouts,
      byMonth: _frequencyByMonth,
      range: _range,
    );

    final cutoff = _range.startDate;
    final bodyEntries = app.measurements
        .where((m) =>
            m.valueByMetric(_bodyMetricKey) != null &&
            (cutoff == null || !m.date.isBefore(cutoff)))
        .toList()
        .reversed
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        app.activeWorkout != null ? 92 : 28,
      ),
      children: [
        // Filtri intervallo temporale (7G, 30G, 3M, 6M, 1A, Tutto)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: TimeRangeFilter.values.map((f) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.label),
                  selected: _range == f,
                  onSelected: (_) => setState(() => _range = f),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // 1. GRAFICO ANDAMENTO ESERCIZIO
        const SectionHeader(title: 'Andamento esercizio (pizzica per zoom)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pulsante selezione esercizio + interruttore linea di tendenza
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickExercise(
                          app,
                          (id) => _selectedExerciseId = id,
                          title: 'Esercizio da analizzare',
                        ),
                        icon: const Icon(Icons.fitness_center_rounded, size: 17),
                        label: Text(
                          selectedEx?.name ?? 'Scegli esercizio',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Trend'),
                      selected: _showTrendLine,
                      onSelected: (v) => setState(() => _showTrendLine = v),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Selettore metrica: Peso Max, 1RM Epley, Volume, Ripetizioni
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _metricChip('1RM (Epley)', '1rm'),
                      const SizedBox(width: 6),
                      _metricChip('Peso max', 'maxWeight'),
                      const SizedBox(width: 6),
                      _metricChip('Volume', 'volume'),
                      const SizedBox(width: 6),
                      _metricChip('Ripetizioni', 'reps'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (exPoints.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'Nessuna sessione registrata per questo esercizio nel periodo scelto.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  // InteractiveViewer abilita zoom e trascinamento sul grafico
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 3.0,
                      child: SizedBox(
                        height: 230,
                        child: _buildExerciseLineChart(exPoints, unit, cs),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 2. VOLUME PER GRUPPO MUSCOLARE (BARRE O RADAR)
        Row(
          children: [
            const Expanded(
              child: SectionHeader(title: 'Volume per gruppo muscolare'),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('Barre')),
                ButtonSegment(value: true, label: Text('Radar')),
              ],
              selected: {_muscleRadarMode},
              onSelectionChanged: (s) =>
                  setState(() => _muscleRadarMode = s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: muscleVolumes.values.every((v) => v <= 0)
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'Completa degli allenamenti per visualizzare la distribuzione del volume.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 250,
                    child: _muscleRadarMode
                        ? _buildMuscleRadarChart(muscleVolumes, cs)
                        : _buildMuscleBarChart(muscleVolumes, unit, cs),
                  ),
          ),
        ),
        const SizedBox(height: 18),

        // 3. FREQUENZA ALLENAMENTI (SETTIMANA O MESE)
        Row(
          children: [
            const Expanded(
              child: SectionHeader(title: 'Frequenza allenamenti'),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('Sett.')),
                ButtonSegment(value: true, label: Text('Mese')),
              ],
              selected: {_frequencyByMonth},
              onSelectionChanged: (s) =>
                  setState(() => _frequencyByMonth = s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: freqSeries.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'Nessun allenamento nel periodo selezionato.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 210,
                    child: _buildFrequencyBarChart(freqSeries, cs),
                  ),
          ),
        ),
        const SizedBox(height: 18),

        // 4. ANDAMENTO PESO CORPOREO E MISURE
        const SectionHeader(title: 'Andamento peso e misure'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _bodyMetricKey,
                  decoration: const InputDecoration(
                    labelText: 'Parametro corporeo',
                  ),
                  items: _bodyMetrics.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value.label),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _bodyMetricKey = v);
                  },
                ),
                const SizedBox(height: 14),
                if (bodyEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Nessuna misurazione registrata per "${_bodyMetrics[_bodyMetricKey]!.label}".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 2.5,
                    child: SizedBox(
                      height: 210,
                      child: _buildBodyLineChart(bodyEntries, unit, cs),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricChip(String label, String key) {
    return ChoiceChip(
      label: Text(label),
      selected: _exerciseMetric == key,
      onSelected: (_) => setState(() => _exerciseMetric = key),
    );
  }

  /// Costruisce il grafico a linee dell'esercizio con eventuale linea di tendenza.
  Widget _buildExerciseLineChart(
    List<ExerciseSessionPoint> points,
    String unit,
    ColorScheme cs,
  ) {
    double extractValue(ExerciseSessionPoint p) {
      switch (_exerciseMetric) {
        case 'maxWeight':
          return AnalyticsService.displayWeight(p.maxWeightKg, unit);
        case 'volume':
          return AnalyticsService.displayWeight(p.totalVolumeKg, unit);
        case 'reps':
          return p.totalReps.toDouble();
        case '1rm':
        default:
          return AnalyticsService.displayWeight(p.estimated1RmKg, unit);
      }
    }

    final values = points.map(extractValue).toList();
    final trend = AnalyticsService.calculateTrendLine(values);

    final mainSpots = <FlSpot>[];
    final trendSpots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < values.length; i++) {
      mainSpots.add(FlSpot(i.toDouble(), values[i]));
      trendSpots.add(FlSpot(i.toDouble(), trend[i]));
      if (values[i] < minY) minY = values[i];
      if (values[i] > maxY) maxY = values[i];
    }

    final spread = (maxY - minY).abs();
    final pad = spread < 1 ? math.max(2.0, maxY * 0.15) : spread * 0.18;
    final suffix = _exerciseMetric == 'reps' ? 'rip' : unit;

    return LineChart(
      LineChartData(
        minY: math.max(0.0, minY - pad),
        maxY: maxY + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant.alphaPct(0.35),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  val >= 1000
                      ? '${(val / 1000).toStringAsFixed(1)}k'
                      : val.round().toString(),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: math.max(1, (points.length / 4).ceil().toDouble()),
              getTitlesWidget: (val, _) {
                final idx = val.round();
                if (idx < 0 || idx >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d/M').format(points[idx].date),
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((barSpot) {
                if (barSpot.barIndex == 1) {
                  return null; // Nasconde tooltip duplicato per la linea trend
                }
                final idx = barSpot.x.round().clamp(0, points.length - 1);
                final pt = points[idx];
                return LineTooltipItem(
                  '${barSpot.y.toStringAsFixed(1)} $suffix\n${formatShortDate(pt.date)}',
                  TextStyle(
                    color: cs.onInverseSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: mainSpots,
            isCurved: true,
            color: cs.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.alphaPct(0.14),
            ),
          ),
          if (_showTrendLine && points.length >= 2)
            LineChartBarData(
              spots: trendSpots,
              isCurved: false,
              color: const Color(0xFF10B981),
              barWidth: 2,
              dashArray: [6, 4],
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  /// Grafico a barre del volume per gruppo muscolare.
  Widget _buildMuscleBarChart(
    Map<String, double> volumes,
    String unit,
    ColorScheme cs,
  ) {
    final entries = volumes.entries
        .where((e) => e.key != MuscleGroups.cardio)
        .toList();
    final maxVal = entries
        .map((e) => AnalyticsService.displayWeight(e.value, unit))
        .fold(0.0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxVal <= 0 ? 100 : maxVal * 1.18,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant.alphaPct(0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (val, _) => Text(
                val >= 1000
                    ? '${(val / 1000).toStringAsFixed(1)}k'
                    : val.round().toString(),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, _) {
                final idx = val.round();
                if (idx < 0 || idx >= entries.length) {
                  return const SizedBox.shrink();
                }
                final short = entries[idx].key.substring(0, 3);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    short,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItem: (group, _, rod, __) {
              final name = entries[group.x].key;
              return BarTooltipItem(
                '$name\n${rod.toY.round()} $unit',
                TextStyle(
                  color: cs.onInverseSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        barGroups: entries.asMap().entries.map((e) {
          final v = AnalyticsService.displayWeight(e.value.value, unit);
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: v,
                color: muscleGroupColor(e.value.key),
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Grafico radar del volume per gruppo muscolare.
  Widget _buildMuscleRadarChart(Map<String, double> volumes, ColorScheme cs) {
    final entries = volumes.entries
        .where((e) => e.key != MuscleGroups.cardio)
        .toList();
    final maxVal =
        entries.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        tickCount: 4,
        ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 8),
        radarBorderData: BorderSide(color: cs.outlineVariant.alphaPct(0.4)),
        gridBorderData: BorderSide(color: cs.outlineVariant.alphaPct(0.35)),
        tickBorderData: BorderSide(color: cs.outlineVariant.alphaPct(0.3)),
        titleTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
        getTitle: (index, _) => RadarChartTitle(text: entries[index].key),
        dataSets: [
          RadarDataSet(
            fillColor: cs.primary.alphaPct(0.28),
            borderColor: cs.primary,
            borderWidth: 2.5,
            entryRadius: 3.5,
            dataEntries: entries
                .map((e) => RadarEntry(value: (e.value / safeMax) * 100.0))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// Grafico a barre della frequenza degli allenamenti (settimanale o mensile).
  Widget _buildFrequencyBarChart(
    List<({String label, int count})> series,
    ColorScheme cs,
  ) {
    final visible = series.length > 12 ? series.sublist(series.length - 12) : series;
    final maxCount = visible.map((e) => e.count).fold(0, math.max);

    return BarChart(
      BarChartData(
        maxY: (maxCount + 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant.alphaPct(0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (v, _) => Text(
                v.round().toString(),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, _) {
                final idx = val.round();
                if (idx < 0 || idx >= visible.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    visible[idx].label,
                    style: TextStyle(fontSize: 9.5, color: cs.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: visible.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.count.toDouble(),
                color: cs.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Grafico a linee per il peso corporeo o qualsiasi circonferenza.
  Widget _buildBodyLineChart(
    List<BodyMeasurement> entries,
    String unit,
    ColorScheme cs,
  ) {
    final isWeight = _bodyMetricKey == 'weight';
    final suffix = isWeight ? unit : _bodyMetrics[_bodyMetricKey]!.unit;
    final spots = <FlSpot>[];
    final rawValues = <double>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < entries.length; i++) {
      final raw = entries[i].valueByMetric(_bodyMetricKey)!;
      final val = isWeight ? AnalyticsService.displayWeight(raw, unit) : raw;
      rawValues.add(val);
      spots.add(FlSpot(i.toDouble(), val));
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
    }

    final trend = AnalyticsService.calculateTrendLine(rawValues);
    final trendSpots = trend
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final pad = (maxY - minY).abs() < 1.0 ? 2.0 : (maxY - minY) * 0.2;

    return LineChart(
      LineChartData(
        minY: math.max(0.0, minY - pad),
        maxY: maxY + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant.alphaPct(0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: math.max(1, (entries.length / 4).ceil().toDouble()),
              getTitlesWidget: (v, _) {
                final idx = v.round();
                if (idx < 0 || idx >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('d/M').format(entries[idx].date),
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItems: (touched) => touched.map((s) {
              if (s.barIndex == 1) return null;
              final idx = s.x.round().clamp(0, entries.length - 1);
              return LineTooltipItem(
                '${s.y.toStringAsFixed(1)} $suffix\n${formatShortDate(entries[idx].date)}',
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
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.alphaPct(0.14),
            ),
          ),
          if (entries.length >= 2)
            LineChartBarData(
              spots: trendSpots,
              color: const Color(0xFF10B981),
              barWidth: 2,
              dashArray: [5, 4],
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: TABELLE (per esercizio, ordinamento, raggruppamento e delta % colore)
  // ===========================================================================

  Widget _buildTablesTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;
    final exId = _resolveDefaultExerciseId(app, _tableExerciseId);
    final selectedEx = exId != null ? app.exerciseMap[exId] : null;

    List<ExerciseSessionPoint> rows = exId != null
        ? AnalyticsService.getExerciseHistory(
            exerciseId: exId,
            workouts: app.completedWorkouts,
            range: _range,
          )
        : [];

    // Applica eventuale raggruppamento per settimana o mese
    if (_tableGrouping != 'session' && rows.isNotEmpty) {
      rows = _groupTableRows(rows, _tableGrouping == 'month');
    }

    // Applica ordinamento scelto
    rows = [...rows]..sort((a, b) {
        int cmp;
        switch (_tableSortBy) {
          case 'weight':
            cmp = a.maxWeightKg.compareTo(b.maxWeightKg);
            break;
          case 'volume':
            cmp = a.totalVolumeKg.compareTo(b.totalVolumeKg);
            break;
          case '1rm':
            cmp = a.estimated1RmKg.compareTo(b.estimated1RmKg);
            break;
          case 'date':
          default:
            cmp = a.date.compareTo(b.date);
        }
        return _tableDescending ? -cmp : cmp;
      });

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        app.activeWorkout != null ? 92 : 28,
      ),
      children: [
        // Selettore esercizio
        OutlinedButton.icon(
          onPressed: () => _pickExercise(
            app,
            (id) => _tableExerciseId = id,
            title: 'Tabella esercizio',
          ),
          icon: const Icon(Icons.table_chart_outlined),
          label: Text(
            selectedEx?.name ?? 'Seleziona esercizio',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 12),

        // Filtri periodo + raggruppamento
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: TimeRangeFilter.values.map((f) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(f.label),
                  selected: _range == f,
                  onSelected: (_) => setState(() => _range = f),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: 'session', label: Text('Sessione')),
                  ButtonSegment(value: 'week', label: Text('Settimana')),
                  ButtonSegment(value: 'month', label: Text('Mese')),
                ],
                selected: {_tableGrouping},
                onSelectionChanged: (s) =>
                    setState(() => _tableGrouping = s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Controlli ordinamento
        Row(
          children: [
            const Text('Ordina:', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _sortChip('Data', 'date'),
                    const SizedBox(width: 6),
                    _sortChip(unit.toUpperCase(), 'weight'),
                    const SizedBox(width: 6),
                    _sortChip('Volume', 'volume'),
                    const SizedBox(width: 6),
                    _sortChip('1RM', '1rm'),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Inverti ordine',
              onPressed: () =>
                  setState(() => _tableDescending = !_tableDescending),
              icon: Icon(
                _tableDescending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (rows.isEmpty)
          const EmptyStateView(
            icon: Icons.table_rows_outlined,
            title: 'Nessun dato in tabella',
            subtitle:
                'Registra almeno un allenamento con questo esercizio per vedere lo storico tabellare.',
          )
        else
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: cs.primary,
                ),
                columns: [
                  DataColumn(
                    label: Text(_tableGrouping == 'session'
                        ? 'Data'
                        : (_tableGrouping == 'week' ? 'Settimana' : 'Mese')),
                  ),
                  const DataColumn(label: Text('Serie'), numeric: true),
                  DataColumn(label: Text('Max $unit'), numeric: true),
                  const DataColumn(label: Text('Rip.'), numeric: true),
                  DataColumn(label: Text('Vol. $unit'), numeric: true),
                  const DataColumn(label: Text('1RM'), numeric: true),
                  const DataColumn(label: Text('Var. Vol')),
                ],
                rows: rows.map((r) {
                  final dateLabel = _tableGrouping == 'month'
                      ? DateFormat('MMM yy', 'it_IT').format(r.date)
                      : (_tableGrouping == 'week'
                          ? 'Sett. ${formatShortDate(r.date)}'
                          : formatShortDate(r.date));
                  return DataRow(
                    cells: [
                      DataCell(Text(dateLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(Text('${r.setsCount}')),
                      DataCell(Text(AnalyticsService.formatWeight(
                          r.maxWeightKg, unit,
                          includeUnit: false))),
                      DataCell(Text('${r.totalReps}')),
                      DataCell(Text(AnalyticsService.displayWeight(
                              r.totalVolumeKg, unit)
                          .round()
                          .toString())),
                      DataCell(Text(AnalyticsService.formatWeight(
                          r.estimated1RmKg, unit,
                          includeUnit: false))),
                      DataCell(DeltaBadge(percent: r.deltaVolumePct)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sortChip(String label, String key) {
    return ChoiceChip(
      label: Text(label),
      selected: _tableSortBy == key,
      onSelected: (_) => setState(() => _tableSortBy = key),
    );
  }

  /// Aggrega le righe della tabella per settimana o per mese ricalcolando i delta.
  List<ExerciseSessionPoint> _groupTableRows(
    List<ExerciseSessionPoint> raw,
    bool byMonth,
  ) {
    final Map<DateTime, List<ExerciseSessionPoint>> grouped = {};
    for (final pt in raw) {
      final key = byMonth
          ? DateTime(pt.date.year, pt.date.month, 1)
          : AnalyticsService.startOfWeek(pt.date);
      grouped.putIfAbsent(key, () => []).add(pt);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    final List<ExerciseSessionPoint> out = [];
    double? prevVol;

    for (final k in sortedKeys) {
      final list = grouped[k]!;
      final sets = list.fold(0, (s, e) => s + e.setsCount);
      final reps = list.fold(0, (s, e) => s + e.totalReps);
      final maxW = list.map((e) => e.maxWeightKg).reduce(math.max);
      final vol = list.fold(0.0, (s, e) => s + e.totalVolumeKg);
      final best1Rm = list.map((e) => e.estimated1RmKg).reduce(math.max);

      out.add(ExerciseSessionPoint(
        workoutId: 0,
        date: k,
        workoutName: '',
        setsCount: sets,
        totalReps: reps,
        maxWeightKg: maxW,
        totalVolumeKg: vol,
        estimated1RmKg: best1Rm,
        deltaVolumePct:
            prevVol != null && prevVol > 0
                ? AnalyticsService.percentChange(prevVol, vol)
                : null,
      ));
      prevVol = vol;
    }
    return out;
  }

  // ===========================================================================
  // TAB 3: CONFRONTI (Periodo, Esercizio nel tempo, A vs B, Misure/Foto, PR)
  // ===========================================================================

  Widget _buildComparisonsTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;
    final monthComp = AnalyticsService.compareMonths(app.completedWorkouts);
    final prs = AnalyticsService.calculatePersonalRecords(
      app.completedWorkouts,
      app.exerciseMap,
    );

    final selfExId = _resolveDefaultExerciseId(app, _compareExSelfId);
    final selfHistory = selfExId != null
        ? AnalyticsService.getExerciseHistory(
            exerciseId: selfExId,
            workouts: app.completedWorkouts,
            range: TimeRangeFilter.all,
          )
        : <ExerciseSessionPoint>[];

    final exAId = _resolveDefaultExerciseId(app, _compareExAId);
    final exBId = _compareExBId ??
        (app.exercises.length > 1 ? app.exercises[1].id : exAId);

    final muscleTotals = AnalyticsService.volumeByMuscleGroup(
      workouts: app.completedWorkouts,
      exerciseMap: app.exerciseMap,
      range: TimeRangeFilter.days30,
    );

    final firstMeasurement =
        app.measurements.isNotEmpty ? app.measurements.last : null;
    final latestMeasurement =
        app.measurements.length >= 2 ? app.measurements.first : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        app.activeWorkout != null ? 92 : 28,
      ),
      children: [
        // 1. PERIODO VS PERIODO (QUESTO MESE VS MESE SCORSO)
        const SectionHeader(title: 'Questo mese vs mese scorso'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _comparisonLine(
                  label: 'Volume totale',
                  current:
                      AnalyticsService.formatVolume(monthComp.currentVolumeKg, unit),
                  previous: AnalyticsService.formatVolume(
                      monthComp.previousVolumeKg, unit),
                  delta: monthComp.volumeDeltaPct,
                ),
                const Divider(),
                _comparisonLine(
                  label: 'Allenamenti',
                  current: '${monthComp.currentWorkouts}',
                  previous: '${monthComp.previousWorkouts}',
                  delta: monthComp.workoutsDeltaPct,
                ),
                const Divider(),
                _comparisonLine(
                  label: 'Durata media',
                  current: '${monthComp.currentAvgMinutes.round()} min',
                  previous: '${monthComp.previousAvgMinutes.round()} min',
                  delta: monthComp.durationDeltaPct,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 2. ESERCIZIO VS SÉ STESSO (PRIMO ALLENAMENTO VS ULTIMO)
        const SectionHeader(title: 'Esercizio nel tempo (Primo vs Ultimo)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickExercise(
                    app,
                    (id) => _compareExSelfId = id,
                    title: 'Confronta esercizio nel tempo',
                  ),
                  icon: const Icon(Icons.compare_arrows_rounded),
                  label: Text(
                    app.exerciseMap[selfExId]?.name ?? 'Scegli esercizio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                if (selfHistory.length < 2)
                  Text(
                    'Servono almeno 2 sessioni registrate su questo esercizio per confrontare inizio e stato attuale.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                else ...[
                  Text(
                    'Dal ${formatItalianDate(selfHistory.first.date)} al ${formatItalianDate(selfHistory.last.date)} (${selfHistory.length} sedute)',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _comparisonLine(
                    label: 'Peso massimo',
                    current: AnalyticsService.formatWeight(
                        selfHistory.last.maxWeightKg, unit),
                    previous: AnalyticsService.formatWeight(
                        selfHistory.first.maxWeightKg, unit),
                    delta: AnalyticsService.percentChange(
                      selfHistory.first.maxWeightKg,
                      selfHistory.last.maxWeightKg,
                    ),
                  ),
                  const Divider(),
                  _comparisonLine(
                    label: '1RM stimato',
                    current: AnalyticsService.formatWeight(
                        selfHistory.last.estimated1RmKg, unit),
                    previous: AnalyticsService.formatWeight(
                        selfHistory.first.estimated1RmKg, unit),
                    delta: AnalyticsService.percentChange(
                      selfHistory.first.estimated1RmKg,
                      selfHistory.last.estimated1RmKg,
                    ),
                  ),
                  const Divider(),
                  _comparisonLine(
                    label: 'Volume seduta',
                    current: AnalyticsService.formatVolume(
                        selfHistory.last.totalVolumeKg, unit),
                    previous: AnalyticsService.formatVolume(
                        selfHistory.first.totalVolumeKg, unit),
                    delta: AnalyticsService.percentChange(
                      selfHistory.first.totalVolumeKg,
                      selfHistory.last.totalVolumeKg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 3. CONFRONTO TRA DUE ESERCIZI O DUE GRUPPI MUSCOLARI
        Row(
          children: [
            const Expanded(
              child: SectionHeader(title: 'Testa a testa (A vs B)'),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('Esercizi')),
                ButtonSegment(value: true, label: Text('Muscoli')),
              ],
              selected: {_compareMuscleMode},
              onSelectionChanged: (s) =>
                  setState(() => _compareMuscleMode = s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: _compareMuscleMode
                ? _buildMuscleVersusCard(muscleTotals, unit, cs)
                : _buildExerciseVersusCard(app, exAId, exBId, unit, cs),
          ),
        ),
        const SizedBox(height: 18),

        // 4. MISURE PRIMA / DOPO
        const SectionHeader(title: 'Misure corporee prima / dopo'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: firstMeasurement == null || latestMeasurement == null
                ? Text(
                    'Registra almeno 2 misurazioni corporee nella scheda "Corpo & Foto" per vedere il confronto prima/dopo.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatItalianDate(firstMeasurement.date)}  →  ${formatItalianDate(latestMeasurement.date)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._bodyMetrics.entries.map((entry) {
                        final v1 = firstMeasurement.valueByMetric(entry.key);
                        final v2 = latestMeasurement.valueByMetric(entry.key);
                        if (v1 == null || v2 == null) {
                          return const SizedBox.shrink();
                        }
                        final isW = entry.key == 'weight';
                        final d1 = isW
                            ? AnalyticsService.displayWeight(v1, unit)
                            : v1;
                        final d2 = isW
                            ? AnalyticsService.displayWeight(v2, unit)
                            : v2;
                        final suffix = isW ? unit : entry.value.unit;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: _comparisonLine(
                            label: entry.value.label,
                            current: '${d2.toStringAsFixed(1)} $suffix',
                            previous: '${d1.toStringAsFixed(1)} $suffix',
                            delta: AnalyticsService.percentChange(d1, d2),
                            invertColors:
                                entry.key == 'waist' || entry.key == 'bodyFat',
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 18),

        // 5. CLASSIFICA RECORD PERSONALI
        SectionHeader(
          title: 'Classifica Record Personali (${prs.length})',
        ),
        if (prs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nessun record personale registrato finora.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: (prs..sort((a, b) => b.best1RmKg.compareTo(a.best1RmKg)))
                  .asMap()
                  .entries
                  .take(15)
                  .map((entry) {
                final rank = entry.key + 1;
                final pr = entry.value;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: rank <= 3
                        ? const Color(0xFFD97706).alphaPct(0.2)
                        : cs.surfaceContainerHighest,
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: rank <= 3
                            ? const Color(0xFFD97706)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  title: Text(
                    pr.exerciseName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${pr.muscleGroup} • ${formatItalianDate(pr.date)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${AnalyticsService.formatWeight(pr.maxWeightKg, unit)} × ${pr.repsAtMaxWeight}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                      Text(
                        '1RM ${AnalyticsService.formatWeight(pr.best1RmKg, unit)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildExerciseVersusCard(
    AppProvider app,
    int? idA,
    int? idB,
    String unit,
    ColorScheme cs,
  ) {
    final histA = idA != null
        ? AnalyticsService.getExerciseHistory(
            exerciseId: idA,
            workouts: app.completedWorkouts,
          )
        : <ExerciseSessionPoint>[];
    final histB = idB != null
        ? AnalyticsService.getExerciseHistory(
            exerciseId: idB,
            workouts: app.completedWorkouts,
          )
        : <ExerciseSessionPoint>[];

    final maxA = histA.isEmpty
        ? 0.0
        : histA.map((e) => e.estimated1RmKg).reduce(math.max);
    final maxB = histB.isEmpty
        ? 0.0
        : histB.map((e) => e.estimated1RmKg).reduce(math.max);
    final volA = histA.fold(0.0, (s, e) => s + e.totalVolumeKg);
    final volB = histB.fold(0.0, (s, e) => s + e.totalVolumeKg);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickExercise(
                  app,
                  (id) => _compareExAId = id,
                  title: 'Esercizio A',
                ),
                child: Text(
                  app.exerciseMap[idA]?.name ?? 'Esercizio A',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('VS', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickExercise(
                  app,
                  (id) => _compareExBId = id,
                  title: 'Esercizio B',
                ),
                child: Text(
                  app.exerciseMap[idB]?.name ?? 'Esercizio B',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _versusBar(
          label: 'Miglior 1RM',
          leftVal: maxA,
          rightVal: maxB,
          leftText: AnalyticsService.formatWeight(maxA, unit),
          rightText: AnalyticsService.formatWeight(maxB, unit),
          cs: cs,
        ),
        const SizedBox(height: 12),
        _versusBar(
          label: 'Volume storico',
          leftVal: volA,
          rightVal: volB,
          leftText: AnalyticsService.formatVolume(volA, unit),
          rightText: AnalyticsService.formatVolume(volB, unit),
          cs: cs,
        ),
      ],
    );
  }

  Widget _buildMuscleVersusCard(
    Map<String, double> totals,
    String unit,
    ColorScheme cs,
  ) {
    final volA = totals[_compareMuscleA] ?? 0;
    final volB = totals[_compareMuscleB] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _compareMuscleA,
                decoration: const InputDecoration(labelText: 'Gruppo A'),
                items: MuscleGroups.all
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _compareMuscleA = v);
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('VS', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _compareMuscleB,
                decoration: const InputDecoration(labelText: 'Gruppo B'),
                items: MuscleGroups.all
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _compareMuscleB = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _versusBar(
          label: 'Volume ultimi 30 giorni',
          leftVal: volA,
          rightVal: volB,
          leftText: AnalyticsService.formatVolume(volA, unit),
          rightText: AnalyticsService.formatVolume(volB, unit),
          cs: cs,
        ),
      ],
    );
  }

  Widget _versusBar({
    required String label,
    required double leftVal,
    required double rightVal,
    required String leftText,
    required String rightText,
    required ColorScheme cs,
  }) {
    final total = leftVal + rightVal;
    final leftRatio = total <= 0 ? 0.5 : (leftVal / total).clamp(0.05, 0.95);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftText,
                style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
            Text(label,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            Text(rightText,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (leftRatio * 100).round(),
                  child: Container(color: cs.primary),
                ),
                Expanded(
                  flex: ((1 - leftRatio) * 100).round(),
                  child: Container(color: const Color(0xFF10B981)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _comparisonLine({
    required String label,
    required String current,
    required String previous,
    required double delta,
    bool invertColors = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'Prima: $previous  →  Ora: $current',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DeltaBadge(percent: delta, invertColors: invertColors),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: CORPO & FOTO (Peso, % grasso, circonferenze, foto + prima/dopo)
  // ===========================================================================

  Widget _buildBodyAndPhotosTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;

    final ProgressPhoto? beforePhoto = app.photos.isNotEmpty
        ? app.photos.firstWhere(
            (p) => p.id == _beforePhotoId,
            orElse: () => app.photos.last,
          )
        : null;
    final ProgressPhoto? afterPhoto = app.photos.isNotEmpty
        ? app.photos.firstWhere(
            (p) => p.id == _afterPhotoId,
            orElse: () => app.photos.first,
          )
        : null;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        app.activeWorkout != null ? 92 : 28,
      ),
      children: [
        // Pulsanti azione rapida
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openMeasurementDialog(app),
                icon: const Icon(Icons.straighten_rounded),
                label: const Text('+ Misurazione'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _openAddPhotoSheet(app),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('+ Foto'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Confronto foto prima / dopo affiancato
        const SectionHeader(title: 'Confronto foto prima / dopo'),
        if (app.photos.length < 2)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aggiungi almeno 2 foto progressi per confrontarle affiancate (Prima vs Dopo).',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _photoCompareSlot(
                          title: 'PRIMA',
                          photo: beforePhoto!,
                          allPhotos: app.photos,
                          unit: unit,
                          onSelect: (id) => setState(() => _beforePhotoId = id),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _photoCompareSlot(
                          title: 'DOPO',
                          photo: afterPhoto!,
                          allPhotos: app.photos,
                          unit: unit,
                          onSelect: (id) => setState(() => _afterPhotoId = id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),

        // Galleria foto salvate
        SectionHeader(title: 'Galleria progressi (${app.photos.length})'),
        if (app.photos.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nessuna foto salvata sul dispositivo.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: app.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, idx) {
                final photo = app.photos[idx];
                return SizedBox(
                  width: 126,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onLongPress: () => _confirmDeletePhoto(app, photo),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: File(photo.filePath).existsSync()
                                ? Image.file(
                                    File(photo.filePath),
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.broken_image_outlined),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatShortDate(photo.date),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  photo.weightKg != null
                                      ? '${photo.pose} • ${AnalyticsService.formatWeight(photo.weightKg!, unit)}'
                                      : photo.pose,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
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
                );
              },
            ),
          ),
        const SizedBox(height: 18),

        // Storico misurazioni corporee
        SectionHeader(title: 'Storico misure (${app.measurements.length})'),
        if (app.measurements.isEmpty)
          const EmptyStateView(
            icon: Icons.monitor_weight_outlined,
            title: 'Nessuna misurazione salvata',
            subtitle:
                'Registra peso, massa grassa e circonferenze per seguire i progressi fisici nel tempo.',
          )
        else
          ...app.measurements.map((m) {
            final details = <String>[];
            if (m.bodyFatPct != null) details.add('BF ${m.bodyFatPct!.toStringAsFixed(1)}%');
            if (m.chestCm != null) details.add('Petto ${m.chestCm} cm');
            if (m.waistCm != null) details.add('Vita ${m.waistCm} cm');
            if (m.hipsCm != null) details.add('Fianchi ${m.hipsCm} cm');
            if (m.rightArmCm != null) details.add('Braccio ${m.rightArmCm} cm');
            if (m.rightThighCm != null) details.add('Coscia ${m.rightThighCm} cm');

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Text(
                        m.weightKg != null
                            ? AnalyticsService.formatWeight(m.weightKg!, unit)
                            : 'Misure corporee',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        formatItalianDate(m.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  subtitle: details.isNotEmpty
                      ? Text(details.join(' • '))
                      : (m.notes.isNotEmpty ? Text(m.notes) : null),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      if (m.id != null) app.deleteBodyMeasurement(m.id!);
                    },
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _photoCompareSlot({
    required String title,
    required ProgressPhoto photo,
    required List<ProgressPhoto> allPhotos,
    required String unit,
    required void Function(int id) onSelect,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        DropdownButton<int>(
          value: photo.id,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          items: allPhotos
              .map((p) => DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      '$title: ${formatShortDate(p.date)} (${p.pose})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (id) {
            if (id != null) onSelect(id);
          },
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: File(photo.filePath).existsSync()
                ? Image.file(File(photo.filePath), fit: BoxFit.cover)
                : Container(
                    color: cs.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          photo.weightKg != null
              ? '${formatItalianDate(photo.date)} • ${AnalyticsService.formatWeight(photo.weightKg!, unit)}'
              : formatItalianDate(photo.date),
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  /// Finestra di inserimento peso, % massa grassa e tutte le circonferenze corporee.
  Future<void> _openMeasurementDialog(AppProvider app) async {
    final unit = app.profile.unit;
    final weightCtrl = TextEditingController();
    final bfCtrl = TextEditingController();
    final chestCtrl = TextEditingController();
    final waistCtrl = TextEditingController();
    final hipsCtrl = TextEditingController();
    final rArmCtrl = TextEditingController();
    final lArmCtrl = TextEditingController();
    final rThighCtrl = TextEditingController();
    final lThighCtrl = TextEditingController();
    final calvesCtrl = TextEditingController();
    final shouldersCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    double? parseNum(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.'));

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Nuova misurazione corporea'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: Text('Data: ${formatItalianDate(selectedDate)}'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: const Text('Cambia'),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(labelText: 'Peso ($unit)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: bfCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Grasso (%)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: chestCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Petto (cm)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: waistCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Vita (cm)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hipsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Fianchi (cm)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: shouldersCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Spalle (cm)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rArmCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Braccio dx (cm)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lArmCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Braccio sx (cm)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rThighCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Coscia dx (cm)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lThighCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Coscia sx (cm)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: calvesCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Polpacci (cm)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                ],
              ),
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
      final rawW = parseNum(weightCtrl);
      await app.saveBodyMeasurement(BodyMeasurement(
        date: selectedDate,
        weightKg:
            rawW != null ? AnalyticsService.toStorageKg(rawW, unit) : null,
        bodyFatPct: parseNum(bfCtrl),
        chestCm: parseNum(chestCtrl),
        waistCm: parseNum(waistCtrl),
        hipsCm: parseNum(hipsCtrl),
        rightArmCm: parseNum(rArmCtrl),
        leftArmCm: parseNum(lArmCtrl),
        rightThighCm: parseNum(rThighCtrl),
        leftThighCm: parseNum(lThighCtrl),
        calvesCm: parseNum(calvesCtrl),
        shouldersCm: parseNum(shouldersCtrl),
        notes: notesCtrl.text.trim(),
      ));
    }

    for (final c in [
      weightCtrl,
      bfCtrl,
      chestCtrl,
      waistCtrl,
      hipsCtrl,
      rArmCtrl,
      lArmCtrl,
      rThighCtrl,
      lThighCtrl,
      calvesCtrl,
      shouldersCtrl,
      notesCtrl,
    ]) {
      c.dispose();
    }
  }

  /// Acquisisce una foto progressi da fotocamera o galleria con posa e peso.
  Future<void> _openAddPhotoSheet(AppProvider app) async {
    final unit = app.profile.unit;
    String pose = 'Fronte';
    final weightCtrl = TextEditingController();
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aggiungi foto progressi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Fronte', 'Lato', 'Schiena'].map((p) {
                    return ChoiceChip(
                      label: Text(p),
                      selected: pose == p,
                      onSelected: (_) => setModalState(() => pose = p),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Peso del giorno (opzionale, $unit)',
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('Fotocamera'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Galleria'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final rawW = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
        await app.addProgressPhoto(
          sourcePath: picked.path,
          date: DateTime.now(),
          pose: pose,
          weightKg:
              rawW != null ? AnalyticsService.toStorageKg(rawW, unit) : null,
        );
      }
    }
    weightCtrl.dispose();
  }

  Future<void> _confirmDeletePhoto(AppProvider app, ProgressPhoto photo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare foto?'),
        content: const Text('La foto verrà rimossa dalla galleria progressi.'),
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
    if (ok == true) {
      await app.deleteProgressPhoto(photo);
    }
  }

  // ===========================================================================
  // TAB 5: STATISTICHE + BILANCIAMENTO + SOVRACCARICO PROGRESSIVO
  // ===========================================================================

  Widget _buildStatsTab(AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    final unit = app.profile.unit;
    final stats = AnalyticsService.calculateGlobalStats(
      app.completedWorkouts,
      app.exerciseMap,
    );
    final suggestions = AnalyticsService.generateOverloadSuggestions(
      workouts: app.completedWorkouts,
      exerciseMap: app.exerciseMap,
      unit: unit,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        app.activeWorkout != null ? 92 : 28,
      ),
      children: [
        // Griglia KPI globali
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.38,
          children: [
            KpiCard(
              icon: Icons.fitness_center_rounded,
              label: 'Totale allenamenti',
              value: '${stats.totalWorkouts}',
              subtitle: '${stats.totalSets} serie totali',
            ),
            KpiCard(
              icon: Icons.scale_rounded,
              iconColor: const Color(0xFF10B981),
              label: 'Volume sollevato',
              value: AnalyticsService.formatVolume(stats.totalVolumeKg, unit),
              subtitle: '${stats.totalPrs} PR battuti',
            ),
            KpiCard(
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF3B82F6),
              label: 'Tempo in palestra',
              value: AnalyticsService.formatDuration(stats.totalDurationSeconds),
              subtitle: 'Media ${stats.avgDurationMinutes.round()} min',
            ),
            KpiCard(
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFFF59E0B),
              label: 'Giorno preferito',
              value: stats.favoriteWeekday,
              subtitle: stats.favoriteTimeSlot,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Abitudini & muscoli
        const SectionHeader(title: 'Profilo di allenamento'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('Esercizio più svolto'),
                subtitle: Text(
                  stats.mostPerformedExercise != null
                      ? '${stats.mostPerformedExercise} (${stats.mostPerformedCount} volte)'
                      : 'Nessun dato ancora',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.trending_up_rounded,
                    color: Color(0xFF10B981)),
                title: const Text('Gruppo muscolare più allenato'),
                subtitle: Text(
                  stats.mostTrainedMuscle ?? 'Nessun dato ancora',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.trending_down_rounded,
                    color: Color(0xFFF59E0B)),
                title: const Text('Gruppo muscolare meno allenato'),
                subtitle: Text(
                  stats.leastTrainedMuscle ?? 'Nessun dato ancora',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Bilanciamento muscolare (funzione extra)
        const SectionHeader(title: 'Bilanciamento muscolare'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _balanceRow(
                  title: 'Rapporto Spinta / Tirata',
                  ratio: stats.pushPullRatio,
                  idealText: 'Ideale: 0.8 – 1.2',
                  cs: cs,
                ),
                const Divider(height: 22),
                _balanceRow(
                  title: 'Rapporto Parte Alta / Gambe',
                  ratio: stats.upperLowerRatio,
                  idealText: 'Ideale: 1.0 – 1.6',
                  cs: cs,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Suggerimenti di sovraccarico progressivo
        const SectionHeader(title: 'Consigli sovraccarico progressivo'),
        if (suggestions.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Completa almeno 1-2 sessioni con carichi registrati per ricevere suggerimenti automatici di aumento peso.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).alphaPct(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_graph_rounded,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    title: Text(
                      s.exerciseName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(s.message),
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _balanceRow({
    required String title,
    required double ratio,
    required String idealText,
    required ColorScheme cs,
  }) {
    final balanced = ratio >= 0.75 && ratio <= 1.65;
    final statusColor =
        balanced ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                idealText,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: statusColor.alphaPct(0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${ratio.toStringAsFixed(2)} : 1',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}