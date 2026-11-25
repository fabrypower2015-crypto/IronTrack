import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/seed_exercises.dart';
import '../models/models.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'irontrack_v1.db';
  static const int _dbVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        goal TEXT NOT NULL,
        level TEXT NOT NULL,
        weekly_goal INTEGER NOT NULL,
        unit TEXT NOT NULL,
        default_rest_seconds INTEGER NOT NULL,
        theme_mode TEXT NOT NULL,
        accent_color TEXT NOT NULL,
        onboarding_completed INTEGER NOT NULL,
        notifications_enabled INTEGER NOT NULL,
        reminder_hour INTEGER NOT NULL,
        reminder_minute INTEGER NOT NULL,
        lock_enabled INTEGER NOT NULL,
        biometric_enabled INTEGER NOT NULL,
        pin_hash TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        equipment TEXT NOT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        weekdays TEXT NOT NULL DEFAULT '[]',
        is_template INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE routine_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        target_sets INTEGER NOT NULL DEFAULT 3,
        target_reps TEXT NOT NULL DEFAULT '8-12',
        rest_seconds INTEGER NOT NULL DEFAULT 90,
        notes TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER,
        name TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        is_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        rest_seconds INTEGER NOT NULL DEFAULT 90,
        notes TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (workout_id) REFERENCES workouts(id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_sets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_exercise_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL DEFAULT 1,
        weight_kg REAL NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        rpe REAL,
        set_type TEXT NOT NULL DEFAULT 'normal',
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_pr INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (workout_exercise_id) REFERENCES workout_exercises(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE body_measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        weight_kg REAL,
        body_fat_pct REAL,
        chest_cm REAL,
        waist_cm REAL,
        hips_cm REAL,
        left_arm_cm REAL,
        right_arm_cm REAL,
        left_thigh_cm REAL,
        right_thigh_cm REAL,
        calves_cm REAL,
        shoulders_cm REAL,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE progress_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        file_path TEXT NOT NULL,
        pose TEXT NOT NULL DEFAULT 'Fronte',
        weight_kg REAL,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        exercise_id INTEGER,
        start_value REAL NOT NULL DEFAULT 0,
        target_value REAL NOT NULL DEFAULT 0,
        current_value REAL NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'kg',
        created_at TEXT NOT NULL,
        deadline TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_workouts_completed ON workouts(is_completed, started_at)');
    await db.execute('CREATE INDEX idx_we_workout ON workout_exercises(workout_id)');
    await db.execute('CREATE INDEX idx_we_exercise ON workout_exercises(exercise_id)');
    await db.execute('CREATE INDEX idx_ws_we ON workout_sets(workout_exercise_id)');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    await db.insert('user_profile', const UserProfile().toMap());

    final Map<String, int> exerciseIdsByName = {};
    for (final ex in seedExercises) {
      final id = await db.insert('exercises', {
        'name': ex.name,
        'muscle_group': ex.muscleGroup,
        'equipment': ex.equipment,
        'is_custom': 0,
        'notes': ex.notes,
      });
      exerciseIdsByName[ex.name] = id;
    }

    for (final template in seedRoutineTemplates) {
      final routineId = await db.insert('routines', {
        'name': template.name,
        'description': template.description,
        'weekdays': jsonEncode(template.weekdays),
        'is_template': 1,
      });

      for (int i = 0; i < template.exercises.length; i++) {
        final item = template.exercises[i];
        final exId = exerciseIdsByName[item.exerciseName];
        if (exId != null) {
          await db.insert('routine_exercises', {
            'routine_id': routineId,
            'exercise_id': exId,
            'order_index': i,
            'target_sets': item.targetSets,
            'target_reps': item.targetReps,
            'rest_seconds': item.restSeconds,
            'notes': '',
          });
        }
      }
    }
  }

  Future<UserProfile> getUserProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      const def = UserProfile();
      await db.insert('user_profile', def.toMap());
      return def;
    }
    return UserProfile.fromMap(rows.first);
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await database;
    final rows = await db.query('exercises', orderBy: 'muscle_group ASC, name ASC');
    return rows.map(Exercise.fromMap).toList();
  }

  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    return db.insert('exercises', exercise.toMap());
  }

  Future<void> updateExercise(Exercise exercise) async {
    final db = await database;
    await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<void> deleteExercise(int id) async {
    final db = await database;
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Routine>> getAllRoutines() async {
    final db = await database;
    final routineRows = await db.query('routines', orderBy: 'id ASC');
    final exRows = await db.query('routine_exercises', orderBy: 'order_index ASC');

    final Map<int, List<RoutineExercise>> byRoutine = {};
    for (final row in exRows) {
      final item = RoutineExercise.fromMap(row);
      byRoutine.putIfAbsent(item.routineId, () => []).add(item);
    }

    return routineRows
        .map((r) => Routine.fromMap(
              r,
              exercises: byRoutine[r['id'] as int] ?? const [],
            ))
        .toList();
  }

  Future<int> saveRoutine(Routine routine) async {
    final db = await database;
    return db.transaction((txn) async {
      int routineId;
      if (routine.id == null) {
        routineId = await txn.insert('routines', routine.toMap());
      } else {
        routineId = routine.id!;
        await txn.update(
          'routines',
          routine.toMap(),
          where: 'id = ?',
          whereArgs: [routineId],
        );
        await txn.delete(
          'routine_exercises',
          where: 'routine_id = ?',
          whereArgs: [routineId],
        );
      }

      for (int i = 0; i < routine.exercises.length; i++) {
        final ex = routine.exercises[i];
        await txn.insert('routine_exercises', {
          'routine_id': routineId,
          'exercise_id': ex.exerciseId,
          'order_index': i,
          'target_sets': ex.targetSets,
          'target_reps': ex.targetReps,
          'rest_seconds': ex.restSeconds,
          'notes': ex.notes,
        });
      }
      return routineId;
    });
  }

  Future<void> deleteRoutine(int id) async {
    final db = await database;
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkoutSession>> getCompletedWorkouts() async {
    final db = await database;
    final rows = await db.query(
      'workouts',
      where: 'is_completed = 1',
      orderBy: 'started_at DESC',
    );
    return _hydrateWorkouts(db, rows);
  }

  Future<WorkoutSession?> getActiveWorkout() async {
    final db = await database;
    final rows = await db.query(
      'workouts',
      where: 'is_completed = 0',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final list = await _hydrateWorkouts(db, rows);
    return list.isEmpty ? null : list.first;
  }

  Future<List<WorkoutSession>> _hydrateWorkouts(
    Database db,
    List> workoutRows,
  ) async {
    if (workoutRows.isEmpty) return [];

    final workoutIds = workoutRows.map((e) => e['id'] as int).toList();
    final placeholders = List.filled(workoutIds.length, '?').join(',');

    final weRows = await db.query(
      'workout_exercises',
      where: 'workout_id IN ($placeholders)',
      whereArgs: workoutIds,
      orderBy: 'order_index ASC',
    );

    final weIds = weRows.map((e) => e['id'] as int).toList();
    final Map<int, List<WorkoutSet>> setsByWe = {};

    if (weIds.isNotEmpty) {
      final setPlaceholders = List.filled(weIds.length, '?').join(',');
      final setRows = await db.query(
        'workout_sets',
        where: 'workout_exercise_id IN ($setPlaceholders)',
        whereArgs: weIds,
        orderBy: 'set_number ASC',
      );
      for (final sRow in setRows) {
        final s = WorkoutSet.fromMap(sRow);
        setsByWe.putIfAbsent(s.workoutExerciseId, () => []).add(s);
      }
    }

    final Map<int, List<WorkoutExerciseLog>> weByWorkout = {};
    for (final weRow in weRows) {
      final weId = weRow['id'] as int;
      final log = WorkoutExerciseLog.fromMap(
        weRow,
        sets: setsByWe[weId] ?? const [],
      );
      weByWorkout.putIfAbsent(log.workoutId, () => []).add(log);
    }

    return workoutRows
        .map((w) => WorkoutSession.fromMap(
              w,
              exercises: weByWorkout[w['id'] as int] ?? const [],
            ))
        .toList();
  }

  Future<WorkoutSession> saveWorkoutSession(WorkoutSession session) async {
    final db = await database;
    final savedId = await db.transaction((txn) async {
      int workoutId;
      if (session.id == null) {
        workoutId = await txn.insert('workouts', session.toMap());
      } else {
        workoutId = session.id!;
        await txn.update(
          'workouts',
          session.toMap(),
          where: 'id = ?',
          whereArgs: [workoutId],
        );
        await txn.delete(
          'workout_exercises',
          where: 'workout_id = ?',
          whereArgs: [workoutId],
        );
      }

      for (int i = 0; i < session.exercises.length; i++) {
        final ex = session.exercises[i];
        final weId = await txn.insert('workout_exercises', {
          'workout_id': workoutId,
          'exercise_id': ex.exerciseId,
          'order_index': i,
          'rest_seconds': ex.restSeconds,
          'notes': ex.notes,
        });

        for (int j = 0; j < ex.sets.length; j++) {
          final s = ex.sets[j];
          await txn.insert('workout_sets', {
            'workout_exercise_id': weId,
            'set_number': j + 1,
            'weight_kg': s.weightKg,
            'reps': s.reps,
            'rpe': s.rpe,
            'set_type': s.setType.code,
            'is_completed': s.isCompleted ? 1 : 0,
            'is_pr': s.isPr ? 1 : 0,
          });
        }
      }
      return workoutId;
    });

    final rows = await db.query('workouts', where: 'id = ?', whereArgs: [savedId]);
    final hydrated = await _hydrateWorkouts(db, rows);
    return hydrated.first;
  }

  Future<void> deleteWorkout(int id) async {
    final db = await database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkoutSet>> getLastCompletedSetsForExercise(int exerciseId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT we.id AS we_id
      FROM workout_exercises we
      INNER JOIN workouts w ON w.id = we.workout_id
      WHERE we.exercise_id = ? AND w.is_completed = 1
      ORDER BY w.started_at DESC
      LIMIT 1
    ''', [exerciseId]);

    if (rows.isEmpty) return [];
    final weId = rows.first['we_id'] as int;
    final setRows = await db.query(
      'workout_sets',
      where: 'workout_exercise_id = ? AND is_completed = 1',
      whereArgs: [weId],
      orderBy: 'set_number ASC',
    );
    return setRows.map(WorkoutSet.fromMap).toList();
  }

  Future<List<BodyMeasurement>> getAllBodyMeasurements() async {
    final db = await database;
    final rows = await db.query('body_measurements', orderBy: 'date DESC');
    return rows.map(BodyMeasurement.fromMap).toList();
  }

  Future<int> saveBodyMeasurement(BodyMeasurement m) async {
    final db = await database;
    if (m.id == null) {
      return db.insert('body_measurements', m.toMap());
    }
    await db.update(
      'body_measurements',
      m.toMap(),
      where: 'id = ?',
      whereArgs: [m.id],
    );
    return m.id!;
  }

  Future<void> deleteBodyMeasurement(int id) async {
    final db = await database;
    await db.delete('body_measurements', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ProgressPhoto>> getAllProgressPhotos() async {
    final db = await database;
    final rows = await db.query('progress_photos', orderBy: 'date DESC');
    return rows.map(ProgressPhoto.fromMap).toList();
  }

  Future<int> insertProgressPhoto(ProgressPhoto photo) async {
    final db = await database;
    return db.insert('progress_photos', photo.toMap());
  }

  Future<void> deleteProgressPhoto(int id) async {
    final db = await database;
    await db.delete('progress_photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FitnessGoal>> getAllGoals() async {
    final db = await database;
    final rows = await db.query('goals', orderBy: 'is_completed ASC, created_at DESC');
    return rows.map(FitnessGoal.fromMap).toList();
  }

  Future<int> saveGoal(FitnessGoal goal) async {
    final db = await database;
    if (goal.id == null) {
      return db.insert('goals', goal.toMap());
    }
    await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
    return goal.id!;
  }

  Future<void> deleteGoal(int id) async {
    final db = await database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> exportFullBackupJson() async {
    final db = await database;
    final payload = <String, dynamic>{
      'app': 'IronTrack',
      'version': _dbVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'user_profile': await db.query('user_profile'),
      'exercises': await db.query('exercises'),
      'routines': await db.query('routines'),
      'routine_exercises': await db.query('routine_exercises'),
      'workouts': await db.query('workouts'),
      'workout_exercises': await db.query('workout_exercises'),
      'workout_sets': await db.query('workout_sets'),
      'body_measurements': await db.query('body_measurements'),
      'progress_photos': await db.query('progress_photos'),
      'goals': await db.query('goals'),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importFullBackupJson(String jsonContent) async {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic> || decoded['app'] != 'IronTrack') {
      throw const FormatException('File di backup IronTrack non valido.');
    }

    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('workout_sets');
      await txn.delete('workout_exercises');
      await txn.delete('workouts');
      await txn.delete('routine_exercises');
      await txn.delete('routines');
      await txn.delete('goals');
      await txn.delete('progress_photos');
      await txn.delete('body_measurements');
      await txn.delete('exercises');
      await txn.delete('user_profile');

      Future<void> insertList(String table) async {
        final rawList = decoded[table];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              await txn.insert(
                table,
                item,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      }

      await insertList('user_profile');
      await insertList('exercises');
      await insertList('routines');
      await insertList('routine_exercises');
      await insertList('workouts');
      await insertList('workout_exercises');
      await insertList('workout_sets');
      await insertList('body_measurements');
      await insertList('progress_photos');
      await insertList('goals');
    });
  }

  Future<String> exportWorkoutsCsv() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        w.started_at AS data,
        w.name AS allenamento,
        w.duration_seconds AS durata_sec,
        e.name AS esercizio,
        e.muscle_group AS gruppo_muscolare,
        s.set_number AS serie,
        s.set_type AS tipo_serie,
        s.weight_kg AS peso_kg,
        s.reps AS ripetizioni,
        s.rpe AS rpe,
        s.is_pr AS record_pr
      FROM workout_sets s
      INNER JOIN workout_exercises we ON we.id = s.workout_exercise_id
      INNER JOIN workouts w ON w.id = we.workout_id
      INNER JOIN exercises e ON e.id = we.exercise_id
      WHERE w.is_completed = 1 AND s.is_completed = 1
      ORDER BY w.started_at DESC, we.order_index ASC, s.set_number ASC
    ''');

    final buffer = StringBuffer();
    buffer.writeln(
      'Data,Allenamento,DurataMin,Esercizio,GruppoMuscolare,Serie,TipoSerie,PesoKg,Ripetizioni,RPE,VolumeKg,PR',
    );

    String esc(Object? v) {
      final str = (v ?? '').toString().replaceAll('"', '""');
      return '"$str"';
    }

    for (final r in rows) {
      final wKg = ((r['peso_kg'] as num?) ?? 0).toDouble();
      final reps = (r['ripetizioni'] as int?) ?? 0;
      final durMin = (((r['durata_sec'] as int?) ?? 0) / 60.0).toStringAsFixed(1);
      final vol = (wKg * reps).toStringAsFixed(1);
      buffer.writeln([
        esc(r['data']),
        esc(r['allenamento']),
        durMin,
        esc(r['esercizio']),
        esc(r['gruppo_muscolare']),
        r['serie'],
        esc(r['tipo_serie']),
        wKg.toStringAsFixed(1),
        reps,
        r['rpe'] ?? '',
        vol,
        (r['record_pr'] as int? ?? 0) == 1 ? 'SI' : 'NO',
      ].join(','));
    }
    return buffer.toString();
  }
}
