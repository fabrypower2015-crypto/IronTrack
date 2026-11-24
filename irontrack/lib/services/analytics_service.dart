import 'dart:math' as math;
import '../models/models.dart';

/// Intervalli temporali usati nei grafici e nelle tabelle.
enum TimeRangeFilter {
  days7('7G', 7),
  days30('30G', 30),
  months3('3M', 90),
  months6('6M', 180),
  year1('1A', 365),
  all('Tutto', null);

  final String label;
  final int? days;

  const TimeRangeFilter(this.label, this.days);

  DateTime? get startDate {
    if (days == null) return null;
    return DateTime.now().subtract(Duration(days: days!));
  }
}

/// Risultato del confronto tra due periodi (es. mese corrente vs precedente).
class PeriodComparison {
  final int currentWorkouts;
  final int previousWorkouts;
  final double currentVolumeKg;
  final double previousVolumeKg;
  final double currentAvgMinutes;
  final double previousAvgMinutes;
  final int currentSets;
  final int previousSets;

  const PeriodComparison({
    required this.currentWorkouts,
    required this.previousWorkouts,
    required this.currentVolumeKg,
    required this.previousVolumeKg,
    required this.currentAvgMinutes,
    required this.previousAvgMinutes,
    required this.currentSets,
    required this.previousSets,
  });

  double get volumeDeltaPct =>
      AnalyticsService.percentChange(previousVolumeKg, currentVolumeKg);

  double get workoutsDeltaPct => AnalyticsService.percentChange(
        previousWorkouts.toDouble(),
        currentWorkouts.toDouble(),
      );

  double get durationDeltaPct =>
      AnalyticsService.percentChange(previousAvgMinutes, currentAvgMinutes);
}

/// Statistiche globali di tutta la carriera in palestra.
class GlobalStats {
  final int totalWorkouts;
  final double totalVolumeKg;
  final int totalDurationSeconds;
  final double avgDurationMinutes;
  final String favoriteWeekday;
  final String favoriteTimeSlot;
  final String? mostPerformedExercise;
  final int mostPerformedCount;
  final String? mostTrainedMuscle;
  final String? leastTrainedMuscle;
  final int totalPrs;
  final int totalSets;
  final double pushPullRatio; // >1 più spinta, <1 più tirata
  final double upperLowerRatio; // >1 più upper, <1 più lower

  const GlobalStats({
    required this.totalWorkouts,
    required this.totalVolumeKg,
    required this.totalDurationSeconds,
    required this.avgDurationMinutes,
    required this.favoriteWeekday,
    required this.favoriteTimeSlot,
    required this.mostPerformedExercise,
    required this.mostPerformedCount,
    required this.mostTrainedMuscle,
    required this.leastTrainedMuscle,
    required this.totalPrs,
    required this.totalSets,
    required this.pushPullRatio,
    required this.upperLowerRatio,
  });
}

/// Risultato del calcolatore dischi per bilanciere.
class PlateBreakdown {
  final double targetWeight;
  final double achievedWeight;
  final double barbellWeight;
  final List<double> platesPerSide;

  const PlateBreakdown({
    required this.targetWeight,
    required this.achievedWeight,
    required this.barbellWeight,
    required this.platesPerSide,
  });
}

/// Serie di riscaldamento suggerita dalla rampa progressiva.
class WarmupSetSuggestion {
  final double weightKg;
  final int reps;
  final int percent;

  const WarmupSetSuggestion({
    required this.weightKg,
    required this.reps,
    required this.percent,
  });
}

/// Motore analitico puro per metriche, grafici, confronti, PR, badge e strumenti.
class AnalyticsService {
  static const double kgToLbFactor = 2.2046226218;

  static const List<String> weekdayShortNames = [
    'Lun',
    'Mar',
    'Mer',
    'Gio',
    'Ven',
    'Sab',
    'Dom',
  ];

  static const List<String> weekdayFullNames = [
    'Lunedì',
    'Martedì',
    'Mercoledì',
    'Giovedì',
    'Venerdì',
    'Sabato',
    'Domenica',
  ];

  /// Converte un peso salvato in kg nell'unità scelta dall'utente.
  static double displayWeight(double weightKg, String unit) {
    return unit == 'lb' ? weightKg * kgToLbFactor : weightKg;
  }

  /// Converte un peso inserito dall'utente nell'unità salvata in DB (kg).
  static double toStorageKg(double inputWeight, String unit) {
    return unit == 'lb' ? inputWeight / kgToLbFactor : inputWeight;
  }

  /// Formatta un peso con decimali puliti (es. "82.5 kg" o "80 kg").
  static String formatWeight(
    double weightKg,
    String unit, {
    bool includeUnit = true,
  }) {
    final val = displayWeight(weightKg, unit);
    final str = (val % 1).abs() < 0.05
        ? val.round().toString()
        : val.toStringAsFixed(1);
    return includeUnit ? '$str $unit' : str;
  }

  /// Formatta un volume grande in modo leggibile (es. "12.4 t" o "4.250 kg").
  static String formatVolume(double volumeKg, String unit) {
    final val = displayWeight(volumeKg, unit);
    if (val >= 10000) {
      final unitLabel = unit == 'lb' ? 'k lb' : 't';
      return '${(val / 1000).toStringAsFixed(1)} $unitLabel';
    }
    return '${val.round()} $unit';
  }

  /// Formatta secondi in formato leggibile (es. "54m" o "1h 12m").
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Formatta cronometro live HH:MM:SS o MM:SS.
  static String formatClock(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Calcola la variazione percentuale tra valore precedente e attuale.
  static double percentChange(double previous, double current) {
    if (previous <= 0) {
      return current > 0 ? 100.0 : 0.0;
    }
    return ((current - previous) / previous) * 100.0;
  }

  /// Inizio della settimana corrente (Lunedì alle 00:00).
  static DateTime startOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return clean.subtract(Duration(days: clean.weekday - 1));
  }

  /// Allenamenti completati nella settimana corrente (Lun-Dom).
  static List<WorkoutSession> workoutsInWeek(
    List<WorkoutSession> workouts,
    DateTime weekMonday,
  ) {
    final nextMonday = weekMonday.add(const Duration(days: 7));
    return workouts
        .where((w) =>
            !w.startedAt.isBefore(weekMonday) &&
            w.startedAt.isBefore(nextMonday))
        .toList();
  }

  /// Volume settimanale attuale vs settimana precedente.
  static ({double currentKg, double previousKg, double deltaPct})
      weeklyVolumeComparison(List<WorkoutSession> workouts) {
    final thisMonday = startOfWeek(DateTime.now());
    final lastMonday = thisMonday.subtract(const Duration(days: 7));

    final currentKg = workoutsInWeek(workouts, thisMonday)
        .fold(0.0, (sum, w) => sum + w.totalVolumeKg);
    final previousKg = workoutsInWeek(workouts, lastMonday)
        .fold(0.0, (sum, w) => sum + w.totalVolumeKg);

    return (
      currentKg: currentKg,
      previousKg: previousKg,
      deltaPct: percentChange(previousKg, currentKg),
    );
  }

  /// Calcola la streak di settimane consecutive con almeno 1 allenamento
  /// e i giorni consecutivi di allenamento.
  static ({int weekStreak, int dayStreak}) calculateStreaks(
    List<WorkoutSession> workouts,
  ) {
    if (workouts.isEmpty) return (weekStreak: 0, dayStreak: 0);

    // Streak settimanale
    final Set<DateTime> trainedWeeks = workouts
        .map((w) => startOfWeek(w.startedAt))
        .toSet();
    DateTime cursorWeek = startOfWeek(DateTime.now());
    if (!trainedWeeks.contains(cursorWeek)) {
      cursorWeek = cursorWeek.subtract(const Duration(days: 7));
    }
    int weekStreak = 0;
    while (trainedWeeks.contains(cursorWeek)) {
      weekStreak++;
      cursorWeek = cursorWeek.subtract(const Duration(days: 7));
    }

    // Streak giornaliera
    final Set<DateTime> trainedDays = workouts
        .map((w) => DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day))
        .toSet();
    final now = DateTime.now();
    DateTime cursorDay = DateTime(now.year, now.month, now.day);
    if (!trainedDays.contains(cursorDay)) {
      cursorDay = cursorDay.subtract(const Duration(days: 1));
    }
    int dayStreak = 0;
    while (trainedDays.contains(cursorDay)) {
      dayStreak++;
      cursorDay = cursorDay.subtract(const Duration(days: 1));
    }

    return (weekStreak: weekStreak, dayStreak: dayStreak);
  }

  /// Mappa data (senza ora) -> numero di allenamenti per la heatmap mensile.
  static Map<DateTime, int> monthlyHeatmap(
    List<WorkoutSession> workouts,
    int year,
    int month,
  ) {
    final Map<DateTime, int> counts = {};
    for (final w in workouts) {
      if (w.startedAt.year == year && w.startedAt.month == month) {
        final key = DateTime(w.startedAt.year, w.startedAt.month, w.startedAt.day);
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Calcola i Record Personali (PR) per ogni esercizio svolto.
  static List<PersonalRecord> calculatePersonalRecords(
    List<WorkoutSession> workouts,
    Map<int, Exercise> exerciseMap,
  ) {
    final Map<int, PersonalRecord> bestByExercise = {};

    for (final w in workouts) {
      for (final log in w.exercises) {
        final ex = exerciseMap[log.exerciseId];
        if (ex == null) continue;

        final validSets = log.sets
            .where((s) =>
                s.isCompleted &&
                s.setType != SetType.warmup &&
                s.weightKg > 0 &&
                s.reps > 0)
            .toList();
        if (validSets.isEmpty) continue;

        double sessionMaxWeight = 0;
        int repsAtMax = 0;
        double sessionBest1Rm = 0;
        for (final s in validSets) {
          if (s.weightKg > sessionMaxWeight ||
              (s.weightKg == sessionMaxWeight && s.reps > repsAtMax)) {
            sessionMaxWeight = s.weightKg;
            repsAtMax = s.reps;
          }
          if (s.estimated1RmKg > sessionBest1Rm) {
            sessionBest1Rm = s.estimated1RmKg;
          }
        }
        final sessionVol = log.totalVolumeKg;

        final existing = bestByExercise[ex.id!];
        if (existing == null) {
          bestByExercise[ex.id!] = PersonalRecord(
            exerciseId: ex.id!,
            exerciseName: ex.name,
            muscleGroup: ex.muscleGroup,
            maxWeightKg: sessionMaxWeight,
            repsAtMaxWeight: repsAtMax,
            best1RmKg: sessionBest1Rm,
            maxVolumeKg: sessionVol,
            date: w.startedAt,
          );
        } else {
          final isNewBest = sessionBest1Rm > existing.best1RmKg ||
              sessionMaxWeight > existing.maxWeightKg;
          bestByExercise[ex.id!] = PersonalRecord(
            exerciseId: ex.id!,
            exerciseName: ex.name,
            muscleGroup: ex.muscleGroup,
            maxWeightKg: math.max(existing.maxWeightKg, sessionMaxWeight),
            repsAtMaxWeight: sessionMaxWeight >= existing.maxWeightKg
                ? repsAtMax
                : existing.repsAtMaxWeight,
            best1RmKg: math.max(existing.best1RmKg, sessionBest1Rm),
            maxVolumeKg: math.max(existing.maxVolumeKg, sessionVol),
            date: isNewBest ? w.startedAt : existing.date,
          );
        }
      }
    }

    final result = bestByExercise.values.toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// Verifica se una serie appena completata batte lo storico (peso massimo o 1RM stimato).
  static bool isSetNewPr({
    required int exerciseId,
    required WorkoutSet candidate,
    required List<WorkoutSession> completedWorkouts,
    required WorkoutSession? currentSession,
  }) {
    if (!candidate.isCompleted ||
        candidate.setType == SetType.warmup ||
        candidate.weightKg <= 0 ||
        candidate.reps <= 0) {
      return false;
    }

    double historicalMaxWeight = 0;
    double historicalBest1Rm = 0;
    bool hasHistory = false;

    for (final w in completedWorkouts) {
      for (final ex in w.exercises) {
        if (ex.exerciseId != exerciseId) continue;
        for (final s in ex.sets) {
          if (!s.isCompleted || s.setType == SetType.warmup || s.weightKg <= 0) {
            continue;
          }
          hasHistory = true;
          if (s.weightKg > historicalMaxWeight) historicalMaxWeight = s.weightKg;
          if (s.estimated1RmKg > historicalBest1Rm) {
            historicalBest1Rm = s.estimated1RmKg;
          }
        }
      }
    }

    // Controlla anche eventuali altre serie già completate nella sessione attiva
    if (currentSession != null) {
      for (final ex in currentSession.exercises) {
        if (ex.exerciseId != exerciseId) continue;
        for (final s in ex.sets) {
          if (identical(s, candidate) ||
              (s.id != null && s.id == candidate.id)) {
            continue;
          }
          if (!s.isCompleted || s.setType == SetType.warmup || s.weightKg <= 0) {
            continue;
          }
          hasHistory = true;
          if (s.weightKg > historicalMaxWeight) historicalMaxWeight = s.weightKg;
          if (s.estimated1RmKg > historicalBest1Rm) {
            historicalBest1Rm = s.estimated1RmKg;
          }
        }
      }
    }

    // Alla primissima volta assoluta su un esercizio, segna PR solo se c'è carico > 0
    if (!hasHistory) return true;

    return candidate.weightKg > historicalMaxWeight ||
        candidate.estimated1RmKg > historicalBest1Rm + 0.05;
  }

  /// Serie temporale completa per un esercizio (usata sia nei grafici sia nelle tabelle).
  static List<ExerciseSessionPoint> getExerciseHistory({
    required int exerciseId,
    required List<WorkoutSession> workouts,
    TimeRangeFilter range = TimeRangeFilter.all,
  }) {
    final cutoff = range.startDate;
    // Ordina cronologicamente dal più vecchio al più recente per calcolare i delta
    final sortedWorkouts = [...workouts]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final List<ExerciseSessionPoint> points = [];
    double? prevVol;
    double? prev1Rm;

    for (final w in sortedWorkouts) {
      if (cutoff != null && w.startedAt.isBefore(cutoff)) continue;
      final matching = w.exercises.where((e) => e.exerciseId == exerciseId).toList();
      if (matching.isEmpty) continue;

      int setsCount = 0;
      int totalReps = 0;
      double maxWeight = 0;
      double totalVol = 0;
      double best1Rm = 0;

      for (final log in matching) {
        for (final s in log.sets) {
          if (!s.isCompleted || s.setType == SetType.warmup) continue;
          setsCount++;
          totalReps += s.reps;
          if (s.weightKg > maxWeight) maxWeight = s.weightKg;
          totalVol += s.weightKg * s.reps;
          if (s.estimated1RmKg > best1Rm) best1Rm = s.estimated1RmKg;
        }
      }

      if (setsCount == 0) continue;

      final double? dVol =
          prevVol != null && prevVol > 0 ? percentChange(prevVol, totalVol) : null;
      final double? d1Rm =
          prev1Rm != null && prev1Rm > 0 ? percentChange(prev1Rm, best1Rm) : null;

      points.add(ExerciseSessionPoint(
        workoutId: w.id ?? 0,
        date: w.startedAt,
        workoutName: w.name,
        setsCount: setsCount,
        totalReps: totalReps,
        maxWeightKg: maxWeight,
        totalVolumeKg: totalVol,
        estimated1RmKg: best1Rm,
        deltaVolumePct: dVol,
        delta1RmPct: d1Rm,
      ));

      prevVol = totalVol;
      prev1Rm = best1Rm;
    }

    return points;
  }

  /// Regressione lineare semplice sui valori Y (indici 0..n-1) per la linea di tendenza.
  static List<double> calculateTrendLine(List<double> values) {
    final n = values.length;
    if (n < 2) return List<double>.from(values);

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumXX = 0;

    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = values[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }

    final denom = n * sumXX - sumX * sumX;
    if (denom == 0) return List<double>.from(values);

    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;

    return List<double>.generate(
      n,
      (i) => math.max(0.0, intercept + slope * i),
    );
  }

  /// Volume aggregato per gruppo muscolare nel periodo selezionato.
  static Map<String, double> volumeByMuscleGroup({
    required List<WorkoutSession> workouts,
    required Map<int, Exercise> exerciseMap,
    TimeRangeFilter range = TimeRangeFilter.days30,
  }) {
    final cutoff = range.startDate;
    final Map<String, double> totals = {
      for (final g in MuscleGroups.all) g: 0.0,
    };

    for (final w in workouts) {
      if (cutoff != null && w.startedAt.isBefore(cutoff)) continue;
      for (final log in w.exercises) {
        final ex = exerciseMap[log.exerciseId];
        if (ex == null) continue;
        totals[ex.muscleGroup] =
            (totals[ex.muscleGroup] ?? 0.0) + log.totalVolumeKg;
      }
    }
    return totals;
  }

  /// Frequenza degli allenamenti raggruppata per settimana o mese.
  static List<({String label, int count})> workoutFrequencySeries({
    required List<WorkoutSession> workouts,
    required bool byMonth,
    TimeRangeFilter range = TimeRangeFilter.months3,
  }) {
    final cutoff = range.startDate;
    final filtered = workouts
        .where((w) => cutoff == null || !w.startedAt.isBefore(cutoff))
        .toList();

    final Map<DateTime, int> buckets = {};
    for (final w in filtered) {
      final bucketKey = byMonth
          ? DateTime(w.startedAt.year, w.startedAt.month, 1)
          : startOfWeek(w.startedAt);
      buckets[bucketKey] = (buckets[bucketKey] ?? 0) + 1;
    }

    final sortedKeys = buckets.keys.toList()..sort();
    return sortedKeys.map((k) {
      final label = byMonth
          ? '${k.month.toString().padLeft(2, '0')}/${k.year.toString().substring(2)}'
          : '${k.day}/${k.month}';
      return (label: label, count: buckets[k] ?? 0);
    }).toList();
  }

  /// Confronto mese corrente vs mese scorso (o ultimi 30g vs 30g precedenti).
  static PeriodComparison compareMonths(List<WorkoutSession> workouts) {
    final now = DateTime.now();
    final startCurrent = DateTime(now.year, now.month, 1);
    final startPrevious = DateTime(now.year, now.month - 1, 1);

    final curr = workouts
        .where((w) => !w.startedAt.isBefore(startCurrent))
        .toList();
    final prev = workouts
        .where((w) =>
            !w.startedAt.isBefore(startPrevious) &&
            w.startedAt.isBefore(startCurrent))
        .toList();

    double avgMin(List<WorkoutSession> list) {
      if (list.isEmpty) return 0;
      final totalSec = list.fold(0, (s, w) => s + w.durationSeconds);
      return (totalSec / list.length) / 60.0;
    }

    return PeriodComparison(
      currentWorkouts: curr.length,
      previousWorkouts: prev.length,
      currentVolumeKg: curr.fold(0.0, (s, w) => s + w.totalVolumeKg),
      previousVolumeKg: prev.fold(0.0, (s, w) => s + w.totalVolumeKg),
      currentAvgMinutes: avgMin(curr),
      previousAvgMinutes: avgMin(prev),
      currentSets: curr.fold(0, (s, w) => s + w.totalCompletedSets),
      previousSets: prev.fold(0, (s, w) => s + w.totalCompletedSets),
    );
  }

  /// Statistiche globali complete inclusi giorno preferito, fascia oraria e bilanciamento.
  static GlobalStats calculateGlobalStats(
    List<WorkoutSession> workouts,
    Map<int, Exercise> exerciseMap,
  ) {
    if (workouts.isEmpty) {
      return const GlobalStats(
        totalWorkouts: 0,
        totalVolumeKg: 0,
        totalDurationSeconds: 0,
        avgDurationMinutes: 0,
        favoriteWeekday: '-',
        favoriteTimeSlot: '-',
        mostPerformedExercise: null,
        mostPerformedCount: 0,
        mostTrainedMuscle: null,
        leastTrainedMuscle: null,
        totalPrs: 0,
        totalSets: 0,
        pushPullRatio: 1.0,
        upperLowerRatio: 1.0,
      );
    }

    double totalVol = 0;
    int totalSec = 0;
    int totalSets = 0;
    int totalPrs = 0;
    final Map<int, int> weekdayCounts = {};
    final Map<String, int> slotCounts = {
      'Mattina (05-12)': 0,
      'Pomeriggio (12-18)': 0,
      'Sera (18-23)': 0,
      'Notte (23-05)': 0,
    };
    final Map<int, int> exerciseCounts = {};
    final Map<String, double> muscleVolumes = {
      for (final m in MuscleGroups.all.where((g) => g != MuscleGroups.cardio))
        m: 0.0,
    };

    for (final w in workouts) {
      totalVol += w.totalVolumeKg;
      totalSec += w.durationSeconds;
      totalSets += w.totalCompletedSets;
      totalPrs += w.prCount;

      weekdayCounts[w.startedAt.weekday] =
          (weekdayCounts[w.startedAt.weekday] ?? 0) + 1;

      final h = w.startedAt.hour;
      if (h >= 5 && h < 12) {
        slotCounts['Mattina (05-12)'] = slotCounts['Mattina (05-12)']! + 1;
      } else if (h >= 12 && h < 18) {
        slotCounts['Pomeriggio (12-18)'] = slotCounts['Pomeriggio (12-18)']! + 1;
      } else if (h >= 18 && h < 23) {
        slotCounts['Sera (18-23)'] = slotCounts['Sera (18-23)']! + 1;
      } else {
        slotCounts['Notte (23-05)'] = slotCounts['Notte (23-05)']! + 1;
      }

      for (final log in w.exercises) {
        exerciseCounts[log.exerciseId] =
            (exerciseCounts[log.exerciseId] ?? 0) + 1;
        final ex = exerciseMap[log.exerciseId];
        if (ex != null && ex.muscleGroup != MuscleGroups.cardio) {
          muscleVolumes[ex.muscleGroup] =
              (muscleVolumes[ex.muscleGroup] ?? 0.0) + log.totalVolumeKg;
        }
      }
    }

    int favDay = 1;
    int favDayCount = -1;
    weekdayCounts.forEach((day, count) {
      if (count > favDayCount) {
        favDayCount = count;
        favDay = day;
      }
    });

    String favSlot = '-';
    int favSlotCount = -1;
    slotCounts.forEach((slot, count) {
      if (count > favSlotCount) {
        favSlotCount = count;
        favSlot = slot;
      }
    });

    int? topExId;
    int topExCount = 0;
    exerciseCounts.forEach((id, count) {
      if (count > topExCount) {
        topExCount = count;
        topExId = id;
      }
    });

    final sortedMuscles = muscleVolumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final mostMuscle =
        sortedMuscles.isNotEmpty && sortedMuscles.first.value > 0
            ? sortedMuscles.first.key
            : null;
    final leastMuscle = sortedMuscles.isNotEmpty ? sortedMuscles.last.key : null;

    // Bilanciamento Spinta vs Tirata
    final pushVol = (muscleVolumes[MuscleGroups.petto] ?? 0) +
        (muscleVolumes[MuscleGroups.spalle] ?? 0) +
        (muscleVolumes[MuscleGroups.tricipiti] ?? 0);
    final pullVol = (muscleVolumes[MuscleGroups.schiena] ?? 0) +
        (muscleVolumes[MuscleGroups.bicipiti] ?? 0);
    final pushPullRatio = pullVol > 0 ? pushVol / pullVol : (pushVol > 0 ? 2.0 : 1.0);

    // Bilanciamento Upper vs Lower
    final upperVol = pushVol + pullVol;
    final lowerVol = (muscleVolumes[MuscleGroups.gambe] ?? 0) +
        (muscleVolumes[MuscleGroups.glutei] ?? 0);
    final upperLowerRatio =
        lowerVol > 0 ? upperVol / lowerVol : (upperVol > 0 ? 2.0 : 1.0);

    return GlobalStats(
      totalWorkouts: workouts.length,
      totalVolumeKg: totalVol,
      totalDurationSeconds: totalSec,
      avgDurationMinutes: (totalSec / workouts.length) / 60.0,
      favoriteWeekday: weekdayFullNames[favDay - 1],
      favoriteTimeSlot: favSlot,
      mostPerformedExercise:
          topExId != null ? exerciseMap[topExId!]?.name : null,
      mostPerformedCount: topExCount,
      mostTrainedMuscle: mostMuscle,
      leastTrainedMuscle: leastMuscle,
      totalPrs: totalPrs,
      totalSets: totalSets,
      pushPullRatio: pushPullRatio,
      upperLowerRatio: upperLowerRatio,
    );
  }

  /// Genera suggerimenti pratici di sovraccarico progressivo analizzando gli ultimi allenamenti.
  static List<OverloadSuggestion> generateOverloadSuggestions({
    required List<WorkoutSession> workouts,
    required Map<int, Exercise> exerciseMap,
    required String unit,
  }) {
    final Map<int, List<WorkoutExerciseLog>> recentByEx = {};

    for (final w in workouts) {
      for (final log in w.exercises) {
        final list = recentByEx.putIfAbsent(log.exerciseId, () => []);
        if (list.length < 3) {
          list.add(log);
        }
      }
    }

    final List<OverloadSuggestion> suggestions = [];

    recentByEx.forEach((exId, logs) {
      final ex = exerciseMap[exId];
      if (ex == null || ex.muscleGroup == MuscleGroups.cardio) return;

      final latest = logs.first;
      final workingSets = latest.sets
          .where((s) =>
              s.isCompleted &&
              s.setType != SetType.warmup &&
              s.weightKg > 0 &&
              s.reps > 0)
          .toList();
      if (workingSets.isEmpty) return;

      final avgWeight = workingSets.fold(0.0, (s, e) => s + e.weightKg) /
          workingSets.length;
      final avgReps = (workingSets.fold(0, (s, e) => s + e.reps) /
              workingSets.length)
          .round();
      final minReps =
          workingSets.map((s) => s.reps).reduce((a, b) => a < b ? a : b);

      // Incremento in base all'attrezzo (bilanciere/macchine +2.5kg, manubri/cavi +1.25-2kg)
      final bool isHeavyCompound = ex.equipment == 'Bilanciere' ||
          ex.equipment == 'Macchina' ||
          ex.equipment == 'Multipower';
      final double incrementKg = isHeavyCompound ? 2.5 : 1.25;

      // Se l'atleta ha consolidato almeno 8-10 ripetizioni su tutte le serie o ripetuto lo stesso carico 2 volte
      bool plateauDetected = false;
      if (logs.length >= 2) {
        final prevMax = logs[1].maxWeightKg;
        if ((latest.maxWeightKg - prevMax).abs() < 0.1 && minReps >= 8) {
          plateauDetected = true;
        }
      }

      if (minReps >= 10 || plateauDetected) {
        final nextKg = avgWeight + incrementKg;
        final incStr = formatWeight(incrementKg, unit);
        final nextStr = formatWeight(nextKg, unit);
        suggestions.add(OverloadSuggestion(
          exerciseId: exId,
          exerciseName: ex.name,
          lastWeightKg: avgWeight,
          lastAvgReps: avgReps,
          suggestedWeightKg: nextKg,
          message:
              'Hai chiuso una media di $avgReps rip. con ${formatWeight(avgWeight, unit)}. Prova ad aumentare di $incStr (target $nextStr).',
        ));
      } else if (minReps >= 6) {
        suggestions.add(OverloadSuggestion(
          exerciseId: exId,
          exerciseName: ex.name,
          lastWeightKg: avgWeight,
          lastAvgReps: avgReps,
          suggestedWeightKg: avgWeight,
          message:
              'Mantieni ${formatWeight(avgWeight, unit)} e punta a +1 ripetizione per serie prima di salire di peso.',
        ));
      }
    });

    return suggestions.take(6).toList();
  }

  /// Calcola tutti i badge e traguardi sbloccati e in corso.
  static List<AchievementBadge> calculateBadges({
    required List<WorkoutSession> workouts,
    required List<BodyMeasurement> measurements,
    required List<ProgressPhoto> photos,
  }) {
    final totalW = workouts.length;
    final totalVolKg = workouts.fold(0.0, (s, w) => s + w.totalVolumeKg);
    final totalPrs = workouts.fold(0, (s, w) => s + w.prCount);
    final streaks = calculateStreaks(workouts);

    AchievementBadge make({
      required String id,
      required String title,
      required String desc,
      required String icon,
      required double current,
      required double target,
      required String suffix,
    }) {
      final ratio = (current / target).clamp(0.0, 1.0);
      return AchievementBadge(
        id: id,
        title: title,
        description: desc,
        iconName: icon,
        unlocked: current >= target,
        progress: ratio,
        progressLabel: '${current.round()}/${target.round()} $suffix',
      );
    }

    return [
      make(
        id: 'first_workout',
        title: 'Primo Passo',
        desc: 'Completa il tuo primo allenamento.',
        icon: 'flag',
        current: totalW.toDouble(),
        target: 1,
        suffix: 'allen.',
      ),
      make(
        id: 'w_10',
        title: 'Abitudine Solida',
        desc: 'Raggiungi 10 allenamenti completati.',
        icon: 'fitness',
        current: totalW.toDouble(),
        target: 10,
        suffix: 'allen.',
      ),
      make(
        id: 'w_50',
        title: 'Veterano della Ghisa',
        desc: 'Completa 50 allenamenti in palestra.',
        icon: 'military',
        current: totalW.toDouble(),
        target: 50,
        suffix: 'allen.',
      ),
      make(
        id: 'w_100',
        title: 'Club dei 100',
        desc: 'Completa 100 sessioni registrate.',
        icon: 'trophy',
        current: totalW.toDouble(),
        target: 100,
        suffix: 'allen.',
      ),
      make(
        id: 'streak_4',
        title: 'Un Mese di Fila',
        desc: 'Allenati per 4 settimane consecutive.',
        icon: 'fire',
        current: streaks.weekStreak.toDouble(),
        target: 4,
        suffix: 'sett.',
      ),
      make(
        id: 'streak_7',
        title: 'Inarrestabile',
        desc: 'Mantieni una streak di 7 settimane di fila.',
        icon: 'bolt',
        current: streaks.weekStreak.toDouble(),
        target: 7,
        suffix: 'sett.',
      ),
      make(
        id: 'pr_1',
        title: 'Primo Record',
        desc: 'Registra il tuo primo Record Personale (PR).',
        icon: 'star',
        current: totalPrs.toDouble(),
        target: 1,
        suffix: 'PR',
      ),
      make(
        id: 'pr_15',
        title: 'Macchina da PR',
        desc: 'Supera 15 record personali.',
        icon: 'workspace',
        current: totalPrs.toDouble(),
        target: 15,
        suffix: 'PR',
      ),
      make(
        id: 'vol_25t',
        title: '25 Tonnellate',
        desc: 'Solleva 25.000 kg complessivi.',
        icon: 'weight',
        current: totalVolKg / 1000.0,
        target: 25,
        suffix: 't',
      ),
      make(
        id: 'vol_100t',
        title: '100 Tonnellate',
        desc: 'Solleva 100.000 kg complessivi.',
        icon: 'diamond',
        current: totalVolKg / 1000.0,
        target: 100,
        suffix: 't',
      ),
      make(
        id: 'body_track',
        title: 'Monitoraggio Fisico',
        desc: 'Registra almeno 5 pesate o misurazioni.',
        icon: 'scale',
        current: measurements.length.toDouble(),
        target: 5,
        suffix: 'misure',
      ),
      make(
        id: 'photo_track',
        title: 'Trasformazione Visiva',
        desc: 'Salva almeno 2 foto progressi per il confronto.',
        icon: 'camera',
        current: photos.length.toDouble(),
        target: 2,
        suffix: 'foto',
      ),
    ];
  }

  /// Calcolatore dischi per lato sul bilanciere (algoritmo greedy sui tagli standard).
  static PlateBreakdown calculateBarbellPlates({
    required double targetWeight,
    required double barbellWeight,
    required List<double> availablePlates,
  }) {
    if (targetWeight <= barbellWeight) {
      return PlateBreakdown(
        targetWeight: targetWeight,
        achievedWeight: barbellWeight,
        barbellWeight: barbellWeight,
        platesPerSide: const [],
      );
    }

    final sorted = [...availablePlates]..sort((a, b) => b.compareTo(a));
    double remainingPerSide = (targetWeight - barbellWeight) / 2.0;
    final List<double> chosen = [];

    for (final plate in sorted) {
      if (plate <= 0) continue;
      while (remainingPerSide + 0.001 >= plate) {
        chosen.add(plate);
        remainingPerSide -= plate;
      }
    }

    final achieved =
        barbellWeight + chosen.fold(0.0, (sum, p) => sum + p) * 2.0;
    return PlateBreakdown(
      targetWeight: targetWeight,
      achievedWeight: achieved,
      barbellWeight: barbellWeight,
      platesPerSide: chosen,
    );
  }

  /// Calcola 1RM stimato con Epley e Brzycki + tabella percentuali 60%–100%.
  static ({double epley, double brzycki, Map<int, double> percentages})
      calculateOneRepMax(double weight, int reps) {
    if (weight <= 0 || reps <= 0) {
      return (epley: 0, brzycki: 0, percentages: const {});
    }
    final epley = reps == 1 ? weight : weight * (1.0 + reps / 30.0);
    final safeReps = reps.clamp(1, 36);
    final brzycki =
        reps == 1 ? weight : weight * (36.0 / (37.0 - safeReps));

    final Map<int, double> pcts = {};
    for (final p in [100, 95, 90, 85, 80, 75, 70, 65, 60]) {
      pcts[p] = epley * (p / 100.0);
    }
    return (epley: epley, brzycki: brzycki, percentages: pcts);
  }

  /// Genera rampa di riscaldamento arrotondata al multiplo di 2.5 kg più vicino.
  static List<WarmupSetSuggestion> generateWarmupRamp(double workingWeightKg) {
    if (workingWeightKg <= 20) {
      return [
        WarmupSetSuggestion(
          weightKg: math.max(5, (workingWeightKg * 0.6).roundToDouble()),
          reps: 10,
          percent: 60,
        ),
      ];
    }

    double round25(double v) => (v / 2.5).round() * 2.5;
    return [
      WarmupSetSuggestion(
        weightKg: math.max(20.0, round25(workingWeightKg * 0.50)),
        reps: 8,
        percent: 50,
      ),
      WarmupSetSuggestion(
        weightKg: math.max(20.0, round25(workingWeightKg * 0.70)),
        reps: 5,
        percent: 70,
      ),
      WarmupSetSuggestion(
        weightKg: math.max(20.0, round25(workingWeightKg * 0.85)),
        reps: 2,
        percent: 85,
      ),
    ];
  }
}