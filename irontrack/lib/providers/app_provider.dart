import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/analytics_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

/// Provider centrale dell'app: gestisce database locale, sessione live,
/// cronometro, timer di recupero, backup, notifiche e sicurezza.
class AppProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = true;
  bool _isUnlocked = true;

  UserProfile _profile = const UserProfile();
  List<Exercise> _exercises = [];
  List<Routine> _routines = [];
  List<WorkoutSession> _completedWorkouts = [];
  WorkoutSession? _activeWorkout;
  List<BodyMeasurement> _measurements = [];
  List<ProgressPhoto> _photos = [];
  List<FitnessGoal> _goals = [];

  /// Cache delle ultime serie completate per esercizio (usata come riferimento nella sessione live).
  final Map<int, List<WorkoutSet>> _lastSetsCache = {};

  // Cronometro sessione live
  Timer? _sessionTimer;
  int _activeElapsedSeconds = 0;

  // Timer recupero automatico
  Timer? _restTimer;
  int _restRemainingSeconds = 0;
  int _restTotalSeconds = 90;
  bool _restRunning = false;

  // Indice tab principale (0: Home, 1: Allenamento, 2: Progressi, 3: Esercizi, 4: Impostazioni)
  int _currentTabIndex = 0;

  // ==================== GETTERS ====================

  bool get isLoading => _isLoading;
  bool get isUnlocked => _isUnlocked;
  UserProfile get profile => _profile;
  List<Exercise> get exercises => _exercises;
  List<Routine> get routines => _routines;
  List<WorkoutSession> get completedWorkouts => _completedWorkouts;
  WorkoutSession? get activeWorkout => _activeWorkout;
  List<BodyMeasurement> get measurements => _measurements;
  List<ProgressPhoto> get photos => _photos;
  List<FitnessGoal> get goals => _goals;

  int get activeElapsedSeconds => _activeElapsedSeconds;
  int get restRemainingSeconds => _restRemainingSeconds;
  int get restTotalSeconds => _restTotalSeconds;
  bool get restRunning => _restRunning;
  int get currentTabIndex => _currentTabIndex;

  Map<int, Exercise> get exerciseMap => {
        for (final e in _exercises)
          if (e.id != null) e.id!: e,
      };

  ThemeMode get themeMode {
    switch (_profile.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Restituisce la scheda consigliata per oggi in base al giorno della settimana
  /// oppure la scheda meno eseguita di recente.
  Routine? get recommendedRoutine {
    if (_routines.isEmpty) return null;
    final todayWeekday = DateTime.now().weekday;
    for (final r in _routines) {
      if (r.weekdays.contains(todayWeekday)) return r;
    }
    // Se nessuna scheda è fissata oggi, ruota in base all'ultima usata
    if (_completedWorkouts.isNotEmpty) {
      final lastRoutineId = _completedWorkouts.first.routineId;
      if (lastRoutineId != null) {
        final idx = _routines.indexWhere((r) => r.id == lastRoutineId);
        if (idx >= 0) {
          return _routines[(idx + 1) % _routines.length];
        }
      }
    }
    return _routines.first;
  }

  void setTabIndex(int index) {
    if (_currentTabIndex == index) return;
    _currentTabIndex = index;
    notifyListeners();
  }

  List<WorkoutSet> getPreviousSetsForExercise(int exerciseId) {
    return _lastSetsCache[exerciseId] ?? const [];
  }

  // ==================== INIZIALIZZAZIONE ====================

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await NotificationService.instance.init();
    await reloadAllData();

    // Richiede sblocco se PIN/biometria è attivo
    _isUnlocked = !_profile.lockEnabled;

    // Ripristina il cronometro se c'era una sessione live lasciata aperta
    if (_activeWorkout != null) {
      _activeElapsedSeconds =
          DateTime.now().difference(_activeWorkout!.startedAt).inSeconds;
      if (_activeElapsedSeconds < 0) _activeElapsedSeconds = 0;
      _startSessionTicker();
      await _preloadLastSetsForSession(_activeWorkout!);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> reloadAllData() async {
    _profile = await _db.getUserProfile();
    _exercises = await _db.getAllExercises();
    _routines = await _db.getAllRoutines();
    _completedWorkouts = await _db.getCompletedWorkouts();
    _activeWorkout = await _db.getActiveWorkout();
    _measurements = await _db.getAllBodyMeasurements();
    _photos = await _db.getAllProgressPhotos();
    _goals = await _db.getAllGoals();
    await _syncDynamicGoals(persist: false);
    notifyListeners();
  }

  // ==================== PROFILO, ONBOARDING & SICUREZZA ====================

  Future<void> updateProfile(UserProfile updated) async {
    _profile = updated;
    await _db.saveUserProfile(updated);
    await syncNotifications();
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String name,
    required String goal,
    required String level,
    required int weeklyGoal,
    required String unit,
  }) async {
    final updated = _profile.copyWith(
      name: name.trim().isEmpty ? 'Atleta' : name.trim(),
      goal: goal,
      level: level,
      weeklyGoal: weeklyGoal,
      unit: unit,
      onboardingCompleted: true,
    );
    await updateProfile(updated);
  }

  String hashPin(String pin) {
    return sha256.convert(utf8.encode('irontrack_salt_$pin')).toString();
  }

  bool verifyPin(String pin) {
    if (_profile.pinHash == null) return true;
    return hashPin(pin) == _profile.pinHash;
  }

  void unlockApp() {
    _isUnlocked = true;
    notifyListeners();
  }

  void lockApp() {
    if (_profile.lockEnabled) {
      _isUnlocked = false;
      notifyListeners();
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) return false;
      final ok = await _localAuth.authenticate(
        localizedReason: 'Sblocca IronTrack con impronta o volto',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (ok) {
        _isUnlocked = true;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncNotifications() async {
    final Map<int, String> routineNamesByDay = {};
    final Set<int> scheduledDays = {};

    for (final r in _routines) {
      for (final d in r.weekdays) {
        scheduledDays.add(d);
        routineNamesByDay.putIfAbsent(d, () => r.name);
      }
    }

    // Se nessuna scheda ha giorni impostati, propone Lun/Mer/Ven di default
    final days = scheduledDays.isNotEmpty
        ? scheduledDays.toList()
        : [1, 3, 5];

    await NotificationService.instance.scheduleWorkoutReminders(
      enabled: _profile.notificationsEnabled,
      weekdays: days,
      hour: _profile.reminderHour,
      minute: _profile.reminderMinute,
      routineNameByWeekday: routineNamesByDay,
    );
  }

  // ==================== LIBRERIA ESERCIZI ====================

  Future<void> addExercise(Exercise exercise) async {
    await _db.insertExercise(exercise.copyWith(isCustom: true));
    _exercises = await _db.getAllExercises();
    notifyListeners();
  }

  Future<void> updateExercise(Exercise exercise) async {
    await _db.updateExercise(exercise);
    _exercises = await _db.getAllExercises();
    notifyListeners();
  }

  Future<void> deleteExercise(int id) async {
    await _db.deleteExercise(id);
    _exercises = await _db.getAllExercises();
    _routines = await _db.getAllRoutines();
    notifyListeners();
  }

  // ==================== SCHEDE / ROUTINE ====================

  Future<void> saveRoutine(Routine routine) async {
    await _db.saveRoutine(routine);
    _routines = await _db.getAllRoutines();
    await syncNotifications();
    notifyListeners();
  }

  Future<void> deleteRoutine(int id) async {
    await _db.deleteRoutine(id);
    _routines = await _db.getAllRoutines();
    await syncNotifications();
    notifyListeners();
  }

  // ==================== SESSIONE DI ALLENAMENTO LIVE ====================

  void _startSessionTicker() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeWorkout != null) {
        _activeElapsedSeconds =
            DateTime.now().difference(_activeWorkout!.startedAt).inSeconds;
        notifyListeners();
      }
    });
  }

  Future<void> _preloadLastSetsForSession(WorkoutSession session) async {
    for (final ex in session.exercises) {
      _lastSetsCache[ex.exerciseId] =
          await _db.getLastCompletedSetsForExercise(ex.exerciseId);
    }
  }

  /// Avvia una nuova sessione live da una scheda oppure vuota (da zero).
  Future<void> startWorkout({Routine? routine, String? customName}) async {
    // Se esiste già una sessione aperta la riprende senza sovrascriverla
    if (_activeWorkout != null) return;

    final now = DateTime.now();
    final List<WorkoutExerciseLog> logs = [];

    if (routine != null) {
      for (int i = 0; i < routine.exercises.length; i++) {
        final rex = routine.exercises[i];
        final prevSets =
            await _db.getLastCompletedSetsForExercise(rex.exerciseId);
        _lastSetsCache[rex.exerciseId] = prevSets;

        final int setCount = rex.targetSets < 1 ? 1 : rex.targetSets;
        final int fallbackReps = _parseFirstReps(rex.targetReps);

        final List<WorkoutSet> initialSets = List.generate(setCount, (idx) {
          final ref = idx < prevSets.length
              ? prevSets[idx]
              : (prevSets.isNotEmpty ? prevSets.last : null);
          return WorkoutSet(
            workoutExerciseId: 0,
            setNumber: idx + 1,
            weightKg: ref?.weightKg ?? 0,
            reps: ref?.reps ?? fallbackReps,
            setType: SetType.normal,
            isCompleted: false,
            isPr: false,
          );
        });

        logs.add(WorkoutExerciseLog(
          workoutId: 0,
          exerciseId: rex.exerciseId,
          orderIndex: i,
          restSeconds: rex.restSeconds,
          notes: rex.notes,
          sets: initialSets,
        ));
      }
    }

    final session = WorkoutSession(
      routineId: routine?.id,
      name: routine?.name ?? (customName ?? 'Allenamento libero'),
      startedAt: now,
      durationSeconds: 0,
      notes: '',
      isCompleted: false,
      exercises: logs,
    );

    _activeWorkout = await _db.saveWorkoutSession(session);
    _activeElapsedSeconds = 0;
    _startSessionTicker();
    notifyListeners();
  }

  /// Duplica un allenamento passato avviandolo subito come nuova sessione live.
  Future<void> duplicatePastWorkoutAsLive(WorkoutSession past) async {
    if (_activeWorkout != null) return;
    final now = DateTime.now();
    final List<WorkoutExerciseLog> clonedLogs = [];

    for (int i = 0; i < past.exercises.length; i++) {
      final ex = past.exercises[i];
      _lastSetsCache[ex.exerciseId] =
          await _db.getLastCompletedSetsForExercise(ex.exerciseId);

      final clonedSets = ex.sets
          .asMap()
          .entries
          .map((entry) => WorkoutSet(
                workoutExerciseId: 0,
                setNumber: entry.key + 1,
                weightKg: entry.value.weightKg,
                reps: entry.value.reps,
                setType: entry.value.setType,
                isCompleted: false,
                isPr: false,
              ))
          .toList();

      clonedLogs.add(WorkoutExerciseLog(
        workoutId: 0,
        exerciseId: ex.exerciseId,
        orderIndex: i,
        restSeconds: ex.restSeconds,
        notes: ex.notes,
        sets: clonedSets,
      ));
    }

    final session = WorkoutSession(
      routineId: past.routineId,
      name: past.name,
      startedAt: now,
      durationSeconds: 0,
      notes: '',
      isCompleted: false,
      exercises: clonedLogs,
    );

    _activeWorkout = await _db.saveWorkoutSession(session);
    _activeElapsedSeconds = 0;
    _startSessionTicker();
    notifyListeners();
  }

  int _parseFirstReps(String targetReps) {
    final match = RegExp(r'\d+').firstMatch(targetReps);
    return match != null ? int.tryParse(match.group(0)!) ?? 10 : 10;
  }

  /// Salva automaticamente in SQLite qualsiasi modifica alla sessione attiva.
  Future<void> _persistActiveWorkout(WorkoutSession updated) async {
    _activeWorkout = await _db.saveWorkoutSession(
      updated.copyWith(durationSeconds: _activeElapsedSeconds),
    );
    notifyListeners();
  }

  Future<void> updateActiveWorkoutMeta({String? name, String? notes}) async {
    if (_activeWorkout == null) return;
    await _persistActiveWorkout(
      _activeWorkout!.copyWith(
        name: name ?? _activeWorkout!.name,
        notes: notes ?? _activeWorkout!.notes,
      ),
    );
  }

  Future<void> addExerciseToActiveWorkout(int exerciseId) async {
    if (_activeWorkout == null) return;
    final prevSets = await _db.getLastCompletedSetsForExercise(exerciseId);
    _lastSetsCache[exerciseId] = prevSets;

    final int setCount = prevSets.isNotEmpty ? prevSets.length.clamp(1, 5) : 3;
    final sets = List.generate(setCount, (idx) {
      final ref = idx < prevSets.length ? prevSets[idx] : null;
      return WorkoutSet(
        workoutExerciseId: 0,
        setNumber: idx + 1,
        weightKg: ref?.weightKg ?? 0,
        reps: ref?.reps ?? 10,
        setType: SetType.normal,
        isCompleted: false,
      );
    });

    final newLog = WorkoutExerciseLog(
      workoutId: _activeWorkout!.id ?? 0,
      exerciseId: exerciseId,
      orderIndex: _activeWorkout!.exercises.length,
      restSeconds: _profile.defaultRestSeconds,
      sets: sets,
    );

    final updatedList = [..._activeWorkout!.exercises, newLog];
    await _persistActiveWorkout(_activeWorkout!.copyWith(exercises: updatedList));
  }

  Future<void> removeExerciseFromActiveWorkout(int exerciseIndex) async {
    if (_activeWorkout == null) return;
    final list = [..._activeWorkout!.exercises]..removeAt(exerciseIndex);
    await _persistActiveWorkout(_activeWorkout!.copyWith(exercises: list));
  }

  Future<void> reorderActiveExercises(int oldIndex, int newIndex) async {
    if (_activeWorkout == null) return;
    final list = [..._activeWorkout!.exercises];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await _persistActiveWorkout(_activeWorkout!.copyWith(exercises: list));
  }

  Future<void> updateActiveExerciseMeta(
    int exerciseIndex, {
    String? notes,
    int? restSeconds,
  }) async {
    if (_activeWorkout == null) return;
    final list = [..._activeWorkout!.exercises];
    final current = list[exerciseIndex];
    list[exerciseIndex] = current.copyWith(
      notes: notes ?? current.notes,
      restSeconds: restSeconds ?? current.restSeconds,
    );
    await _persistActiveWorkout(_activeWorkout!.copyWith(exercises: list));
  }

  Future<void> addSetToActiveExercise(int exerciseIndex) async {
    if (_activeWorkout == null) return;
    final list = [..._activeWorkout!.exercises];
    final ex = list[exerciseIndex];
    final last = ex.sets.isNotEmpty ? ex.sets.last : null;
    final newSet = WorkoutSet(
      workoutExerciseId: ex.id ?? 0,
      setNumber: ex.sets.length + 1,
      weightKg: last?.weightKg ?? 0,
      reps: last?.reps ?? 10,
      setType: SetType.normal,
      isCompleted: false,
    );
    list[exerciseIndex] = ex.copyWith(sets: [...ex.sets, newSet]);
    await _persistActiveWorkout(_activeWorkout!.copyWith(exercises: list));
  }

  /// Inserisce automaticamente le serie di riscaldamento prima delle serie allenanti.
  Future<void> insertWarmupRampForExercise(
    int exerciseIndex,
    double targetWeightKg,
  ) async {
    if (_activeWorkout == null) return;
    final list = [..._activeWorkout!.exercises];
    final ex = list[exerciseIndex];
    final ramp = AnalyticsService.generateWarmupRamp(targetWeightKg);

    final warmupSets = ramp
        .map((r) => WorkoutSet(
              workoutExerciseId: ex.id ?? 0,
              setNumber: 1,
              weightKg: r.weightKg,
              reps: r.reps,
              setType: SetType.warmup,
              isCompleted: false,
            ))
        .toList();

    final merged = [...warmupSets, ...ex.sets];
    final renumbered = merged
        .asMap()
        .entries
        .map((e) => e.value.copyWith(setNumber: e.key + 1))
        .toList();

    list[exerciseIndex] = ex.copyWith(sets: renumbered);
    await _persistActiveWorkout(_activeWorkout!.copyWith(exercises: list));
  }

  Future<void> removeSetFromActiveExercise(
    int exerciseIndex,
    int setIndex,
  ) async {
    if (_activeWorkout == null) return;
    final list = [..._activeWorkout!.exercises];
    final ex = list[exerciseIndex];
    final sets = [...ex.sets]..removeAt(setIndex);
    final renumbered = sets
        .asMap()
        .entries
        .map((e) => e.value.copyWith(setNumber: e.key + 1))
        .toList();
    list[exerciseIndex] = ex.copyWith(sets: renumbered);
    await _persistActiveWorkout(_activeWorkout!.copyWith(exercises: list));
  }

  /// Aggiorna una serie live. Se viene spuntata come completata:
  /// 1) verifica subito se è un nuovo PR,
  /// 2) avvia il timer di recupero automatico.
  Future<bool> updateSetInActiveWorkout(
    int exerciseIndex,
    int setIndex,
    WorkoutSet updatedSet, {
    bool triggerRestOnComplete = true,
  }) async {
    if (_activeWorkout == null) return false;
    final list = [..._activeWorkout!.exercises];
    final ex = list[exerciseIndex];
    final sets = [...ex.sets];
    final previousSet = sets[setIndex];

    bool becameCompleted = !previousSet.isCompleted && updatedSet.isCompleted;
    bool isNewPr = false;

    if (updatedSet.isCompleted) {
      isNewPr = AnalyticsService.isSetNewPr(
        exerciseId: ex.exerciseId,
        candidate: updatedSet,
        completedWorkouts: _completedWorkouts,
        currentSession: _activeWorkout,
      );
    }

    sets[setIndex] = updatedSet.copyWith(isPr: isNewPr);
    list[exerciseIndex] = ex.copyWith(sets: sets);
    await _persistActiveWorkout(_activeWorkout!.copyWith(exercises: list));

    if (becameCompleted) {
      if (isNewPr) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      if (triggerRestOnComplete &&
          updatedSet.setType != SetType.warmup &&
          ex.restSeconds > 0) {
        startRestTimer(ex.restSeconds);
      }
    }
    return isNewPr && becameCompleted;
  }

  /// Conclude e salva definitivamente la sessione live nello storico.
  Future<WorkoutSession?> finishActiveWorkout() async {
    if (_activeWorkout == null) return null;
    stopRestTimer();
    _sessionTimer?.cancel();

    final completed = _activeWorkout!.copyWith(
      endedAt: DateTime.now(),
      durationSeconds: _activeElapsedSeconds > 0 ? _activeElapsedSeconds : 60,
      isCompleted: true,
    );

    final saved = await _db.saveWorkoutSession(completed);
    _activeWorkout = null;
    _activeElapsedSeconds = 0;
    _completedWorkouts = await _db.getCompletedWorkouts();
    await _syncDynamicGoals(persist: true);
    notifyListeners();
    return saved;
  }

  /// Annulla la sessione live senza salvarla nello storico.
  Future<void> discardActiveWorkout() async {
    if (_activeWorkout == null) return;
    stopRestTimer();
    _sessionTimer?.cancel();
    if (_activeWorkout!.id != null) {
      await _db.deleteWorkout(_activeWorkout!.id!);
    }
    _activeWorkout = null;
    _activeElapsedSeconds = 0;
    notifyListeners();
  }

  // ==================== TIMER DI RECUPERO ====================

  void startRestTimer(int seconds) {
    _restTimer?.cancel();
    _restTotalSeconds = seconds < 5 ? 5 : seconds;
    _restRemainingSeconds = _restTotalSeconds;
    _restRunning = true;
    notifyListeners();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restRemainingSeconds <= 1) {
        timer.cancel();
        _restRemainingSeconds = 0;
        _restRunning = false;
        HapticFeedback.vibrate();
        SystemSound.play(SystemSoundType.alert);
        NotificationService.instance.showRestCompletedNotification();
        notifyListeners();
      } else {
        _restRemainingSeconds--;
        notifyListeners();
      }
    });
  }

  void adjustRestTimer(int deltaSeconds) {
    if (!_restRunning) return;
    _restRemainingSeconds = (_restRemainingSeconds + deltaSeconds).clamp(5, 600);
    if (_restRemainingSeconds > _restTotalSeconds) {
      _restTotalSeconds = _restRemainingSeconds;
    }
    notifyListeners();
  }

  void stopRestTimer() {
    _restTimer?.cancel();
    _restRunning = false;
    _restRemainingSeconds = 0;
    notifyListeners();
  }

  // ==================== STORICO ALLENAMENTI ====================

  Future<void> updateCompletedWorkout(WorkoutSession session) async {
    await _db.saveWorkoutSession(session.copyWith(isCompleted: true));
    _completedWorkouts = await _db.getCompletedWorkouts();
    await _syncDynamicGoals(persist: true);
    notifyListeners();
  }

  Future<void> deleteCompletedWorkout(int id) async {
    await _db.deleteWorkout(id);
    _completedWorkouts = await _db.getCompletedWorkouts();
    await _syncDynamicGoals(persist: true);
    notifyListeners();
  }

  // ==================== MISURE CORPOREE & FOTO ====================

  Future<void> saveBodyMeasurement(BodyMeasurement m) async {
    await _db.saveBodyMeasurement(m);
    _measurements = await _db.getAllBodyMeasurements();
    await _syncDynamicGoals(persist: true);
    notifyListeners();
  }

  Future<void> deleteBodyMeasurement(int id) async {
    await _db.deleteBodyMeasurement(id);
    _measurements = await _db.getAllBodyMeasurements();
    await _syncDynamicGoals(persist: true);
    notifyListeners();
  }

  /// Copia la foto scelta in una cartella permanente dell'app e la salva nel DB.
  Future<void> addProgressPhoto({
    required String sourcePath,
    required DateTime date,
    required String pose,
    double? weightKg,
    String notes = '',
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'progress_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = p.join(photosDir.path, fileName);
    await File(sourcePath).copy(destPath);

    await _db.insertProgressPhoto(ProgressPhoto(
      date: date,
      filePath: destPath,
      pose: pose,
      weightKg: weightKg,
      notes: notes,
    ));

    _photos = await _db.getAllProgressPhotos();
    notifyListeners();
  }

  Future<void> deleteProgressPhoto(ProgressPhoto photo) async {
    if (photo.id != null) {
      await _db.deleteProgressPhoto(photo.id!);
    }
    try {
      final f = File(photo.filePath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    _photos = await _db.getAllProgressPhotos();
    notifyListeners();
  }

  // ==================== OBIETTIVI ====================

  Future<void> saveGoal(FitnessGoal goal) async {
    await _db.saveGoal(goal);
    _goals = await _db.getAllGoals();
    await _syncDynamicGoals(persist: true);
    notifyListeners();
  }

  Future<void> deleteGoal(int id) async {
    await _db.deleteGoal(id);
    _goals = await _db.getAllGoals();
    notifyListeners();
  }

  /// Aggiorna automaticamente il valore attuale degli obiettivi collegati a
  /// esercizi (PR), peso corporeo o numero di allenamenti.
  Future<void> _syncDynamicGoals({required bool persist}) async {
    if (_goals.isEmpty) return;
    final prs =
        AnalyticsService.calculatePersonalRecords(_completedWorkouts, exerciseMap);
    final Map<int, PersonalRecord> prByEx = {
      for (final pr in prs) pr.exerciseId: pr,
    };
    final double? latestBodyWeight = _measurements
        .where((m) => m.weightKg != null)
        .map((m) => m.weightKg!)
        .firstOrNull;

    final List<FitnessGoal> updated = [];
    for (final g in _goals) {
      double newVal = g.currentValue;
      if (g.type == 'exercise_weight' && g.exerciseId != null) {
        final pr = prByEx[g.exerciseId!];
        if (pr != null) newVal = pr.maxWeightKg;
      } else if (g.type == 'body_weight' && latestBodyWeight != null) {
        newVal = latestBodyWeight;
      } else if (g.type == 'workouts_count') {
        newVal = _completedWorkouts.length.toDouble();
      }

      final bool reached = g.targetValue >= g.startValue
          ? newVal >= g.targetValue
          : newVal <= g.targetValue;

      final next = g.copyWith(currentValue: newVal, isCompleted: reached);
      updated.add(next);
      if (persist && (next.currentValue != g.currentValue || next.isCompleted != g.isCompleted)) {
        await _db.saveGoal(next);
      }
    }
    _goals = updated;
  }

  // ==================== BACKUP JSON & EXPORT CSV ====================

  Future<void> exportAndShareJsonBackup() async {
    final content = await _db.exportFullBackupJson();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File(p.join(dir.path, 'irontrack_backup_$stamp.json'));
    await file.writeAsString(content);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Backup completo IronTrack ($stamp)',
    );
  }

  Future<void> exportAndShareCsv() async {
    final csv = await _db.exportWorkoutsCsv();
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File(p.join(dir.path, 'irontrack_allenamenti_$stamp.csv'));
    await file.writeAsString(csv);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Esportazione CSV allenamenti IronTrack ($stamp)',
    );
  }

  /// Apre il selettore file del telefono e ripristina un backup JSON IronTrack.
  Future<bool> importJsonBackupFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return false;
    final content = await File(result.files.single.path!).readAsString();
    await _db.importFullBackupJson(content);
    await reloadAllData();
    return true;
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }
}