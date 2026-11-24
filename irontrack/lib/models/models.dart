import 'dart:convert';

/// Gruppi muscolari ufficiali dell'app.
class MuscleGroups {
  static const String petto = 'Petto';
  static const String schiena = 'Schiena';
  static const String spalle = 'Spalle';
  static const String bicipiti = 'Bicipiti';
  static const String tricipiti = 'Tricipiti';
  static const String gambe = 'Gambe';
  static const String glutei = 'Glutei';
  static const String addome = 'Addome';
  static const String cardio = 'Cardio';

  static const List<String> all = [
    petto,
    schiena,
    spalle,
    bicipiti,
    tricipiti,
    gambe,
    glutei,
    addome,
    cardio,
  ];
}

/// Attrezzi comuni per gli esercizi.
class EquipmentTypes {
  static const List<String> all = [
    'Bilanciere',
    'Manubri',
    'Macchina',
    'Cavi',
    'Corpo libero',
    'Kettlebell',
    'Multipower',
    'Elastico',
    'Cardio',
    'Altro',
  ];
}

/// Tipo di serie nella sessione live.
enum SetType {
  warmup('warmup', 'Risc.', 'Riscaldamento'),
  normal('normal', 'Norm.', 'Normale'),
  dropSet('dropset', 'Drop', 'Drop Set'),
  failure('failure', 'Ced.', 'Al cedimento');

  final String code;
  final String shortLabel;
  final String label;

  const SetType(this.code, this.shortLabel, this.label);

  static SetType fromCode(String? code) {
    return SetType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SetType.normal,
    );
  }
}

/// Profilo utente salvato in locale.
class UserProfile {
  final int id;
  final String name;
  final String goal; // Massa, Forza, Definizione, Ricomposizione
  final String level; // Principiante, Intermedio, Avanzato
  final int weeklyGoal;
  final String unit; // 'kg' o 'lb'
  final int defaultRestSeconds;
  final String themeMode; // 'system', 'light', 'dark'
  final String accentColor;
  final bool onboardingCompleted;
  final bool notificationsEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool lockEnabled;
  final bool biometricEnabled;
  final String? pinHash;

  const UserProfile({
    this.id = 1,
    this.name = 'Atleta',
    this.goal = 'Massa',
    this.level = 'Intermedio',
    this.weeklyGoal = 3,
    this.unit = 'kg',
    this.defaultRestSeconds = 90,
    this.themeMode = 'dark',
    this.accentColor = 'orange',
    this.onboardingCompleted = false,
    this.notificationsEnabled = false,
    this.reminderHour = 18,
    this.reminderMinute = 0,
    this.lockEnabled = false,
    this.biometricEnabled = false,
    this.pinHash,
  });

  UserProfile copyWith({
    String? name,
    String? goal,
    String? level,
    int? weeklyGoal,
    String? unit,
    int? defaultRestSeconds,
    String? themeMode,
    String? accentColor,
    bool? onboardingCompleted,
    bool? notificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? lockEnabled,
    bool? biometricEnabled,
    String? pinHash,
    bool clearPin = false,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      level: level ?? this.level,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      unit: unit ?? this.unit,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'goal': goal,
        'level': level,
        'weekly_goal': weeklyGoal,
        'unit': unit,
        'default_rest_seconds': defaultRestSeconds,
        'theme_mode': themeMode,
        'accent_color': accentColor,
        'onboarding_completed': onboardingCompleted ? 1 : 0,
        'notifications_enabled': notificationsEnabled ? 1 : 0,
        'reminder_hour': reminderHour,
        'reminder_minute': reminderMinute,
        'lock_enabled': lockEnabled ? 1 : 0,
        'biometric_enabled': biometricEnabled ? 1 : 0,
        'pin_hash': pinHash,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: (map['id'] as int?) ?? 1,
        name: (map['name'] as String?) ?? 'Atleta',
        goal: (map['goal'] as String?) ?? 'Massa',
        level: (map['level'] as String?) ?? 'Intermedio',
        weeklyGoal: (map['weekly_goal'] as int?) ?? 3,
        unit: (map['unit'] as String?) ?? 'kg',
        defaultRestSeconds: (map['default_rest_seconds'] as int?) ?? 90,
        themeMode: (map['theme_mode'] as String?) ?? 'dark',
        accentColor: (map['accent_color'] as String?) ?? 'orange',
        onboardingCompleted: (map['onboarding_completed'] as int? ?? 0) == 1,
        notificationsEnabled: (map['notifications_enabled'] as int? ?? 0) == 1,
        reminderHour: (map['reminder_hour'] as int?) ?? 18,
        reminderMinute: (map['reminder_minute'] as int?) ?? 0,
        lockEnabled: (map['lock_enabled'] as int? ?? 0) == 1,
        biometricEnabled: (map['biometric_enabled'] as int? ?? 0) == 1,
        pinHash: map['pin_hash'] as String?,
      );
}

/// Esercizio nella libreria.
class Exercise {
  final int? id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final bool isCustom;
  final String notes;

  const Exercise({
    this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.isCustom = false,
    this.notes = '',
  });

  Exercise copyWith({
    int? id,
    String? name,
    String? muscleGroup,
    String? equipment,
    bool? isCustom,
    String? notes,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      isCustom: isCustom ?? this.isCustom,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'muscle_group': muscleGroup,
        'equipment': equipment,
        'is_custom': isCustom ? 1 : 0,
        'notes': notes,
      };

  factory Exercise.fromMap(Map<String, dynamic> map) => Exercise(
        id: map['id'] as int?,
        name: map['name'] as String,
        muscleGroup: map['muscle_group'] as String,
        equipment: map['equipment'] as String,
        isCustom: (map['is_custom'] as int? ?? 0) == 1,
        notes: (map['notes'] as String?) ?? '',
      );
}

/// Esercizio configurato all'interno di una scheda/routine.
class RoutineExercise {
  final int? id;
  final int routineId;
  final int exerciseId;
  final int orderIndex;
  final int targetSets;
  final String targetReps; // es. "8-10" oppure "12"
  final int restSeconds;
  final String notes;

  const RoutineExercise({
    this.id,
    required this.routineId,
    required this.exerciseId,
    required this.orderIndex,
    this.targetSets = 3,
    this.targetReps = '8-12',
    this.restSeconds = 90,
    this.notes = '',
  });

  RoutineExercise copyWith({
    int? id,
    int? routineId,
    int? exerciseId,
    int? orderIndex,
    int? targetSets,
    String? targetReps,
    int? restSeconds,
    String? notes,
  }) {
    return RoutineExercise(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      exerciseId: exerciseId ?? this.exerciseId,
      orderIndex: orderIndex ?? this.orderIndex,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'routine_id': routineId,
        'exercise_id': exerciseId,
        'order_index': orderIndex,
        'target_sets': targetSets,
        'target_reps': targetReps,
        'rest_seconds': restSeconds,
        'notes': notes,
      };

  factory RoutineExercise.fromMap(Map<String, dynamic> map) => RoutineExercise(
        id: map['id'] as int?,
        routineId: map['routine_id'] as int,
        exerciseId: map['exercise_id'] as int,
        orderIndex: (map['order_index'] as int?) ?? 0,
        targetSets: (map['target_sets'] as int?) ?? 3,
        targetReps: (map['target_reps'] as String?) ?? '8-12',
        restSeconds: (map['rest_seconds'] as int?) ?? 90,
        notes: (map['notes'] as String?) ?? '',
      );
}

/// Scheda di allenamento (es. Push, Pull, Legs, Full Body).
class Routine {
  final int? id;
  final String name;
  final String description;
  final List<int> weekdays; // 1 = Lun ... 7 = Dom
  final bool isTemplate;
  final List<RoutineExercise> exercises;

  const Routine({
    this.id,
    required this.name,
    this.description = '',
    this.weekdays = const [],
    this.isTemplate = false,
    this.exercises = const [],
  });

  Routine copyWith({
    int? id,
    String? name,
    String? description,
    List<int>? weekdays,
    bool? isTemplate,
    List<RoutineExercise>? exercises,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      weekdays: weekdays ?? this.weekdays,
      isTemplate: isTemplate ?? this.isTemplate,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'weekdays': jsonEncode(weekdays),
        'is_template': isTemplate ? 1 : 0,
      };

  factory Routine.fromMap(
    Map<String, dynamic> map, {
    List<RoutineExercise> exercises = const [],
  }) {
    List<int> days = [];
    final raw = map['weekdays'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        days = decoded.map((e) => (e as num).toInt()).toList();
      } catch (_) {}
    }
    return Routine(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      weekdays: days,
      isTemplate: (map['is_template'] as int? ?? 0) == 1,
      exercises: exercises,
    );
  }
}

/// Singola serie eseguita in una sessione.
class WorkoutSet {
  final int? id;
  final int workoutExerciseId;
  final int setNumber;
  final double weightKg; // sempre salvato internamente in kg
  final int reps;
  final double? rpe;
  final SetType setType;
  final bool isCompleted;
  final bool isPr;

  const WorkoutSet({
    this.id,
    required this.workoutExerciseId,
    required this.setNumber,
    this.weightKg = 0,
    this.reps = 0,
    this.rpe,
    this.setType = SetType.normal,
    this.isCompleted = false,
    this.isPr = false,
  });

  double get volumeKg => setType == SetType.warmup ? 0 : weightKg * reps;

  /// Formula di Epley per stima 1RM.
  double get estimated1RmKg {
    if (weightKg <= 0 || reps <= 0 || setType == SetType.warmup) return 0;
    if (reps == 1) return weightKg;
    return weightKg * (1 + reps / 30.0);
  }

  WorkoutSet copyWith({
    int? id,
    int? workoutExerciseId,
    int? setNumber,
    double? weightKg,
    int? reps,
    double? rpe,
    bool clearRpe = false,
    SetType? setType,
    bool? isCompleted,
    bool? isPr,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
      setNumber: setNumber ?? this.setNumber,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      rpe: clearRpe ? null : (rpe ?? this.rpe),
      setType: setType ?? this.setType,
      isCompleted: isCompleted ?? this.isCompleted,
      isPr: isPr ?? this.isPr,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'workout_exercise_id': workoutExerciseId,
        'set_number': setNumber,
        'weight_kg': weightKg,
        'reps': reps,
        'rpe': rpe,
        'set_type': setType.code,
        'is_completed': isCompleted ? 1 : 0,
        'is_pr': isPr ? 1 : 0,
      };

  factory WorkoutSet.fromMap(Map<String, dynamic> map) => WorkoutSet(
        id: map['id'] as int?,
        workoutExerciseId: map['workout_exercise_id'] as int,
        setNumber: (map['set_number'] as int?) ?? 1,
        weightKg: ((map['weight_kg'] as num?) ?? 0).toDouble(),
        reps: (map['reps'] as int?) ?? 0,
        rpe: (map['rpe'] as num?)?.toDouble(),
        setType: SetType.fromCode(map['set_type'] as String?),
        isCompleted: (map['is_completed'] as int? ?? 0) == 1,
        isPr: (map['is_pr'] as int? ?? 0) == 1,
      );
}

/// Blocco esercizio all'interno di una sessione di allenamento.
class WorkoutExerciseLog {
  final int? id;
  final int workoutId;
  final int exerciseId;
  final int orderIndex;
  final int restSeconds;
  final String notes;
  final List<WorkoutSet> sets;

  const WorkoutExerciseLog({
    this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.orderIndex,
    this.restSeconds = 90,
    this.notes = '',
    this.sets = const [],
  });

  double get totalVolumeKg => sets
      .where((s) => s.isCompleted && s.setType != SetType.warmup)
      .fold(0.0, (sum, s) => sum + s.weightKg * s.reps);

  int get completedSetsCount => sets.where((s) => s.isCompleted).length;

  double get maxWeightKg {
    final valid =
        sets.where((s) => s.isCompleted && s.setType != SetType.warmup);
    if (valid.isEmpty) return 0;
    return valid.map((s) => s.weightKg).reduce((a, b) => a > b ? a : b);
  }

  double get best1RmKg {
    final valid =
        sets.where((s) => s.isCompleted && s.setType != SetType.warmup);
    if (valid.isEmpty) return 0;
    return valid.map((s) => s.estimated1RmKg).reduce((a, b) => a > b ? a : b);
  }

  WorkoutExerciseLog copyWith({
    int? id,
    int? workoutId,
    int? exerciseId,
    int? orderIndex,
    int? restSeconds,
    String? notes,
    List<WorkoutSet>? sets,
  }) {
    return WorkoutExerciseLog(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      orderIndex: orderIndex ?? this.orderIndex,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      sets: sets ?? this.sets,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'workout_id': workoutId,
        'exercise_id': exerciseId,
        'order_index': orderIndex,
        'rest_seconds': restSeconds,
        'notes': notes,
      };

  factory WorkoutExerciseLog.fromMap(
    Map<String, dynamic> map, {
    List<WorkoutSet> sets = const [],
  }) =>
      WorkoutExerciseLog(
        id: map['id'] as int?,
        workoutId: map['workout_id'] as int,
        exerciseId: map['exercise_id'] as int,
        orderIndex: (map['order_index'] as int?) ?? 0,
        restSeconds: (map['rest_seconds'] as int?) ?? 90,
        notes: (map['notes'] as String?) ?? '',
        sets: sets,
      );
}

/// Sessione completa di allenamento (attiva o conclusa).
class WorkoutSession {
  final int? id;
  final int? routineId;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String notes;
  final bool isCompleted;
  final List<WorkoutExerciseLog> exercises;

  const WorkoutSession({
    this.id,
    this.routineId,
    required this.name,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.notes = '',
    this.isCompleted = false,
    this.exercises = const [],
  });

  double get totalVolumeKg =>
      exercises.fold(0.0, (sum, e) => sum + e.totalVolumeKg);

  int get totalCompletedSets =>
      exercises.fold(0, (sum, e) => sum + e.completedSetsCount);

  int get prCount => exercises.fold(
      0, (sum, e) => sum + e.sets.where((s) => s.isCompleted && s.isPr).length);

  WorkoutSession copyWith({
    int? id,
    int? routineId,
    String? name,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? notes,
    bool? isCompleted,
    List<WorkoutExerciseLog>? exercises,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'routine_id': routineId,
        'name': name,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'duration_seconds': durationSeconds,
        'notes': notes,
        'is_completed': isCompleted ? 1 : 0,
      };

  factory WorkoutSession.fromMap(
    Map<String, dynamic> map, {
    List<WorkoutExerciseLog> exercises = const [],
  }) =>
      WorkoutSession(
        id: map['id'] as int?,
        routineId: map['routine_id'] as int?,
        name: map['name'] as String,
        startedAt: DateTime.parse(map['started_at'] as String),
        endedAt: map['ended_at'] != null
            ? DateTime.parse(map['ended_at'] as String)
            : null,
        durationSeconds: (map['duration_seconds'] as int?) ?? 0,
        notes: (map['notes'] as String?) ?? '',
        isCompleted: (map['is_completed'] as int? ?? 0) == 1,
        exercises: exercises,
      );
}

/// Misurazioni corporee con data.
class BodyMeasurement {
  final int? id;
  final DateTime date;
  final double? weightKg;
  final double? bodyFatPct;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? leftArmCm;
  final double? rightArmCm;
  final double? leftThighCm;
  final double? rightThighCm;
  final double? calvesCm;
  final double? shouldersCm;
  final String notes;

  const BodyMeasurement({
    this.id,
    required this.date,
    this.weightKg,
    this.bodyFatPct,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.leftArmCm,
    this.rightArmCm,
    this.leftThighCm,
    this.rightThighCm,
    this.calvesCm,
    this.shouldersCm,
    this.notes = '',
  });

  double? valueByMetric(String key) {
    switch (key) {
      case 'weight':
        return weightKg;
      case 'bodyFat':
        return bodyFatPct;
      case 'chest':
        return chestCm;
      case 'waist':
        return waistCm;
      case 'hips':
        return hipsCm;
      case 'rightArm':
        return rightArmCm;
      case 'leftArm':
        return leftArmCm;
      case 'rightThigh':
        return rightThighCm;
      case 'leftThigh':
        return leftThighCm;
      case 'calves':
        return calvesCm;
      case 'shoulders':
        return shouldersCm;
      default:
        return weightKg;
    }
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'weight_kg': weightKg,
        'body_fat_pct': bodyFatPct,
        'chest_cm': chestCm,
        'waist_cm': waistCm,
        'hips_cm': hipsCm,
        'left_arm_cm': leftArmCm,
        'right_arm_cm': rightArmCm,
        'left_thigh_cm': leftThighCm,
        'right_thigh_cm': rightThighCm,
        'calves_cm': calvesCm,
        'shoulders_cm': shouldersCm,
        'notes': notes,
      };

  factory BodyMeasurement.fromMap(Map<String, dynamic> map) => BodyMeasurement(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        bodyFatPct: (map['body_fat_pct'] as num?)?.toDouble(),
        chestCm: (map['chest_cm'] as num?)?.toDouble(),
        waistCm: (map['waist_cm'] as num?)?.toDouble(),
        hipsCm: (map['hips_cm'] as num?)?.toDouble(),
        leftArmCm: (map['left_arm_cm'] as num?)?.toDouble(),
        rightArmCm: (map['right_arm_cm'] as num?)?.toDouble(),
        leftThighCm: (map['left_thigh_cm'] as num?)?.toDouble(),
        rightThighCm: (map['right_thigh_cm'] as num?)?.toDouble(),
        calvesCm: (map['calves_cm'] as num?)?.toDouble(),
        shouldersCm: (map['shoulders_cm'] as num?)?.toDouble(),
        notes: (map['notes'] as String?) ?? '',
      );
}

/// Foto progressi salvata localmente sul dispositivo.
class ProgressPhoto {
  final int? id;
  final DateTime date;
  final String filePath;
  final String pose; // Fronte, Lato, Schiena
  final double? weightKg;
  final String notes;

  const ProgressPhoto({
    this.id,
    required this.date,
    required this.filePath,
    this.pose = 'Fronte',
    this.weightKg,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date.toIso8601String(),
        'file_path': filePath,
        'pose': pose,
        'weight_kg': weightKg,
        'notes': notes,
      };

  factory ProgressPhoto.fromMap(Map<String, dynamic> map) => ProgressPhoto(
        id: map['id'] as int?,
        date: DateTime.parse(map['date'] as String),
        filePath: map['file_path'] as String,
        pose: (map['pose'] as String?) ?? 'Fronte',
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        notes: (map['notes'] as String?) ?? '',
      );
}

/// Obiettivi personali tracciati con barra di progresso.
class FitnessGoal {
  final int? id;
  final String title;
  final String type; // 'exercise_weight', 'body_weight', 'workouts_count', 'custom'
  final int? exerciseId;
  final double startValue;
  final double targetValue;
  final double currentValue;
  final String unit;
  final DateTime createdAt;
  final DateTime? deadline;
  final bool isCompleted;

  const FitnessGoal({
    this.id,
    required this.title,
    required this.type,
    this.exerciseId,
    required this.startValue,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.createdAt,
    this.deadline,
    this.isCompleted = false,
  });

  double get progressRatio {
    final totalDelta = targetValue - startValue;
    if (totalDelta == 0) {
      return currentValue >= targetValue ? 1.0 : 0.0;
    }
    final achieved = currentValue - startValue;
    return (achieved / totalDelta).clamp(0.0, 1.0);
  }

  FitnessGoal copyWith({
    int? id,
    String? title,
    String? type,
    int? exerciseId,
    double? startValue,
    double? targetValue,
    double? currentValue,
    String? unit,
    DateTime? createdAt,
    DateTime? deadline,
    bool? isCompleted,
  }) {
    return FitnessGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      exerciseId: exerciseId ?? this.exerciseId,
      startValue: startValue ?? this.startValue,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'type': type,
        'exercise_id': exerciseId,
        'start_value': startValue,
        'target_value': targetValue,
        'current_value': currentValue,
        'unit': unit,
        'created_at': createdAt.toIso8601String(),
        'deadline': deadline?.toIso8601String(),
        'is_completed': isCompleted ? 1 : 0,
      };

  factory FitnessGoal.fromMap(Map<String, dynamic> map) => FitnessGoal(
        id: map['id'] as int?,
        title: map['title'] as String,
        type: map['type'] as String,
        exerciseId: map['exercise_id'] as int?,
        startValue: ((map['start_value'] as num?) ?? 0).toDouble(),
        targetValue: ((map['target_value'] as num?) ?? 0).toDouble(),
        currentValue: ((map['current_value'] as num?) ?? 0).toDouble(),
        unit: (map['unit'] as String?) ?? 'kg',
        createdAt: DateTime.parse(map['created_at'] as String),
        deadline: map['deadline'] != null
            ? DateTime.parse(map['deadline'] as String)
            : null,
        isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      );
}

/// Record personale calcolato dai dati salvati.
class PersonalRecord {
  final int exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final double maxWeightKg;
  final int repsAtMaxWeight;
  final double best1RmKg;
  final double maxVolumeKg;
  final DateTime date;

  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
    required this.maxWeightKg,
    required this.repsAtMaxWeight,
    required this.best1RmKg,
    required this.maxVolumeKg,
    required this.date,
  });
}

/// Traguardo / Badge calcolato dinamicamente.
class AchievementBadge {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final bool unlocked;
  final double progress; // 0.0 - 1.0
  final String progressLabel;

  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.unlocked,
    required this.progress,
    required this.progressLabel,
  });
}

/// Suggerimento di sovraccarico progressivo per un esercizio.
class OverloadSuggestion {
  final int exerciseId;
  final String exerciseName;
  final double lastWeightKg;
  final int lastAvgReps;
  final double suggestedWeightKg;
  final String message;

  const OverloadSuggestion({
    required this.exerciseId,
    required this.exerciseName,
    required this.lastWeightKg,
    required this.lastAvgReps,
    required this.suggestedWeightKg,
    required this.message,
  });
}

/// Riga dati per grafici e tabelle di un esercizio.
class ExerciseSessionPoint {
  final int workoutId;
  final DateTime date;
  final String workoutName;
  final int setsCount;
  final int totalReps;
  final double maxWeightKg;
  final double totalVolumeKg;
  final double estimated1RmKg;
  final double? deltaVolumePct;
  final double? delta1RmPct;

  const ExerciseSessionPoint({
    required this.workoutId,
    required this.date,
    required this.workoutName,
    required this.setsCount,
    required this.totalReps,
    required this.maxWeightKg,
    required this.totalVolumeKg,
    required this.estimated1RmKg,
    this.deltaVolumePct,
    this.delta1RmPct,
  });
}