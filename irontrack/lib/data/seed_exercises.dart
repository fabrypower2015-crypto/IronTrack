import '../models/models.dart';

/// Voce di definizione per popolare gli esercizi precompilati nel database.
class SeedExerciseDef {
  final String name;
  final String muscleGroup;
  final String equipment;
  final String notes;

  const SeedExerciseDef(
    this.name,
    this.muscleGroup,
    this.equipment, [
    this.notes = '',
  ]);
}

/// Voce di esercizio all'interno di una scheda template iniziale.
class SeedRoutineExerciseDef {
  final String exerciseName;
  final int targetSets;
  final String targetReps;
  final int restSeconds;

  const SeedRoutineExerciseDef(
    this.exerciseName,
    this.targetSets,
    this.targetReps,
    this.restSeconds,
  );
}

/// Definizione di una scheda template pronta all'uso.
class SeedRoutineTemplateDef {
  final String name;
  final String description;
  final List<int> weekdays;
  final List<SeedRoutineExerciseDef> exercises;

  const SeedRoutineTemplateDef({
    required this.name,
    required this.description,
    required this.weekdays,
    required this.exercises,
  });
}

/// 108 esercizi precompilati divisi nei 9 gruppi muscolari principali.
const List<SeedExerciseDef> seedExercises = [
  // ===================== PETTO (14) =====================
  SeedExerciseDef('Panca piana con bilanciere', MuscleGroups.petto, 'Bilanciere', 'Esercizio fondamentale per pettorali, deltoidi anteriori e tricipiti.'),
  SeedExerciseDef('Panca inclinata con bilanciere', MuscleGroups.petto, 'Bilanciere', 'Enfasi sui fasci clavicolari del pettorale.'),
  SeedExerciseDef('Panca declinata con bilanciere', MuscleGroups.petto, 'Bilanciere', 'Enfasi sulla porzione inferiore del pettorale.'),
  SeedExerciseDef('Panca piana con manubri', MuscleGroups.petto, 'Manubri', 'Maggiore escursione articolare e lavoro stabilizzatore.'),
  SeedExerciseDef('Panca inclinata con manubri', MuscleGroups.petto, 'Manubri', 'Inclinazione consigliata tra 30 e 45 gradi.'),
  SeedExerciseDef('Panca piana al multipower', MuscleGroups.petto, 'Multipower', 'Traiettoria guidata ideale per carichi controllati.'),
  SeedExerciseDef('Chest press alla macchina', MuscleGroups.petto, 'Macchina', 'Spinta guidata per pettorali.'),
  SeedExerciseDef('Chest press inclinata convergente', MuscleGroups.petto, 'Macchina', 'Traiettoria convergente sui fasci alti.'),
  SeedExerciseDef('Croci su panca piana con manubri', MuscleGroups.petto, 'Manubri', 'Isolamento in allungamento del pettorale.'),
  SeedExerciseDef('Croci su panca inclinata con manubri', MuscleGroups.petto, 'Manubri', 'Isolamento dei fasci superiori del petto.'),
  SeedExerciseDef('Croci ai cavi alti', MuscleGroups.petto, 'Cavi', 'Tensione costante in chiusura verso il basso.'),
  SeedExerciseDef('Croci ai cavi bassi', MuscleGroups.petto, 'Cavi', 'Chiusura dal basso verso l\'alto per petto alto.'),
  SeedExerciseDef('Pectoral machine (Peck Deck)', MuscleGroups.petto, 'Macchina', 'Adduzione orizzontale guidata.'),
  SeedExerciseDef('Dip alle parallele per petto', MuscleGroups.petto, 'Corpo libero', 'Busto leggermente inclinato in avanti.'),

  // ===================== SCHIENA (15) =====================
  SeedExerciseDef('Stacco da terra classico', MuscleGroups.schiena, 'Bilanciere', 'Alzata multiarticolare per catena posteriore completa.'),
  SeedExerciseDef('Trazioni alla sbarra presa prona', MuscleGroups.schiena, 'Corpo libero', 'Ampiezza dorsale e grande rotondo.'),
  SeedExerciseDef('Trazioni alla sbarra presa supina', MuscleGroups.schiena, 'Corpo libero', 'Forte coinvolgimento di dorsali e bicipiti.'),
  SeedExerciseDef('Lat machine presa larga', MuscleGroups.schiena, 'Macchina', 'Tirata verticale per ampiezza schiena.'),
  SeedExerciseDef('Lat machine presa inversa', MuscleGroups.schiena, 'Macchina', 'Tirata verticale con focus su dorsale basso.'),
  SeedExerciseDef('Lat machine triangolo (presa neutra)', MuscleGroups.schiena, 'Macchina', 'Tirata verticale con presa stretta neutra.'),
  SeedExerciseDef('Rematore con bilanciere', MuscleGroups.schiena, 'Bilanciere', 'Spessore schiena, romboidi e trapezi.'),
  SeedExerciseDef('Rematore Pendlay', MuscleGroups.schiena, 'Bilanciere', 'Ripartenza da terra ad ogni ripetizione.'),
  SeedExerciseDef('Rematore con manubrio singolo', MuscleGroups.schiena, 'Manubri', 'Lavoro unilaterale in appoggio su panca.'),
  SeedExerciseDef('Rematore T-Bar', MuscleGroups.schiena, 'Bilanciere', 'Tirata pesante per centro schiena.'),
  SeedExerciseDef('Pulley basso seduto', MuscleGroups.schiena, 'Cavi', 'Tirata orizzontale con tensione continua.'),
  SeedExerciseDef('Rowing machine (Vertical Row)', MuscleGroups.schiena, 'Macchina', 'Tirata orizzontale con appoggio sternale.'),
  SeedExerciseDef('Pullover ai cavi a braccia tese', MuscleGroups.schiena, 'Cavi', 'Isolamento del gran dorsale.'),
  SeedExerciseDef('Iperestensioni lombari', MuscleGroups.schiena, 'Corpo libero', 'Rinforzo erettori spinali e catena posteriore.'),
  SeedExerciseDef('Scrollate con manubri (Shrugs)', MuscleGroups.schiena, 'Manubri', 'Isolamento del trapezio superiore.'),

  // ===================== SPALLE (13) =====================
  SeedExerciseDef('Military press con bilanciere', MuscleGroups.spalle, 'Bilanciere', 'Spinta verticale in piedi con core attivo.'),
  SeedExerciseDef('Lento avanti con manubri', MuscleGroups.spalle, 'Manubri', 'Spinta verticale seduto o in piedi.'),
  SeedExerciseDef('Arnold press con manubri', MuscleGroups.spalle, 'Manubri', 'Rotazione completa del deltoide anteriore e laterale.'),
  SeedExerciseDef('Shoulder press alla macchina', MuscleGroups.spalle, 'Macchina', 'Spinta verticale guidata.'),
  SeedExerciseDef('Lento avanti al multipower', MuscleGroups.spalle, 'Multipower', 'Spinta verticale su binario fisso.'),
  SeedExerciseDef('Alzate laterali con manubri', MuscleGroups.spalle, 'Manubri', 'Isolamento capo laterale del deltoide.'),
  SeedExerciseDef('Alzate laterali ai cavi', MuscleGroups.spalle, 'Cavi', 'Tensione costante in tutto il movimento.'),
  SeedExerciseDef('Alzate laterali alla macchina', MuscleGroups.spalle, 'Macchina', 'Abduzione spalla guidata.'),
  SeedExerciseDef('Alzate frontali con manubri', MuscleGroups.spalle, 'Manubri', 'Isolamento capo anteriore del deltoide.'),
  SeedExerciseDef('Alzate posteriori a busto flesso', MuscleGroups.spalle, 'Manubri', 'Isolamento deltoide posteriore.'),
  SeedExerciseDef('Reverse pec deck', MuscleGroups.spalle, 'Macchina', 'Deltoidi posteriori e parte alta della schiena.'),
  SeedExerciseDef('Face pull ai cavi', MuscleGroups.spalle, 'Cavi', 'Salute della cuffia dei rotatori e deltoide posteriore.'),
  SeedExerciseDef('Tirate al mento con bilanciere EZ', MuscleGroups.spalle, 'Bilanciere', 'Presa media per deltoide laterale e trapezio.'),

  // ===================== BICIPITI (11) =====================
  SeedExerciseDef('Curl bilanciere dritto', MuscleGroups.bicipiti, 'Bilanciere', 'Fondamentale per massa dei bicipiti.'),
  SeedExerciseDef('Curl bilanciere EZ', MuscleGroups.bicipiti, 'Bilanciere', 'Riduce lo stress sui polsi.'),
  SeedExerciseDef('Curl manubri alternato', MuscleGroups.bicipiti, 'Manubri', 'Con supinazione completa del polso.'),
  SeedExerciseDef('Curl a martello (Hammer curl)', MuscleGroups.bicipiti, 'Manubri', 'Focus su brachiale e brachioradiale.'),
  SeedExerciseDef('Curl su panca inclinata', MuscleGroups.bicipiti, 'Manubri', 'Massimo allungamento del capo lungo.'),
  SeedExerciseDef('Curl alla panca Scott', MuscleGroups.bicipiti, 'Bilanciere', 'Elimina lo slancio della schiena.'),
  SeedExerciseDef('Curl di concentrazione', MuscleGroups.bicipiti, 'Manubri', 'Isolamento unilaterale seduto.'),
  SeedExerciseDef('Curl ai cavi bassi con barra', MuscleGroups.bicipiti, 'Cavi', 'Tensione costante in salita e discesa.'),
  SeedExerciseDef('Curl ai cavi con corda', MuscleGroups.bicipiti, 'Cavi', 'Variante a martello al cavo basso.'),
  SeedExerciseDef('Curl alla macchina (Biceps machine)', MuscleGroups.bicipiti, 'Macchina', 'Flessione gomito guidata.'),
  SeedExerciseDef('Curl inverso con bilanciere EZ', MuscleGroups.bicipiti, 'Bilanciere', 'Focus su avambracci e brachioradiale.'),

  // ===================== TRICIPITI (11) =====================
  SeedExerciseDef('Panca piana presa stretta', MuscleGroups.tricipiti, 'Bilanciere', 'Multiarticolare pesante per tricipiti.'),
  SeedExerciseDef('French press con bilanciere EZ', MuscleGroups.tricipiti, 'Bilanciere', 'Estensione sdraiato per capo lungo e laterale.'),
  SeedExerciseDef('Pushdown tricipiti ai cavi con barra', MuscleGroups.tricipiti, 'Cavi', 'Estensione gomito al cavo alto.'),
  SeedExerciseDef('Pushdown tricipiti ai cavi con corda', MuscleGroups.tricipiti, 'Cavi', 'Aprire la corda in fondo al movimento.'),
  SeedExerciseDef('Estensioni sopra la testa con manubrio', MuscleGroups.tricipiti, 'Manubri', 'Grande allungamento del capo lungo.'),
  SeedExerciseDef('Estensioni sopra la testa al cavo', MuscleGroups.tricipiti, 'Cavi', 'Tensione continua in massimo allungamento.'),
  SeedExerciseDef('Dip alle parallele per tricipiti', MuscleGroups.tricipiti, 'Corpo libero', 'Busto verticale e gomiti stretti.'),
  SeedExerciseDef('Dip tra due panche', MuscleGroups.tricipiti, 'Corpo libero', 'Variante accessibile a corpo libero o zavorrata.'),
  SeedExerciseDef('Kickback con manubrio', MuscleGroups.tricipiti, 'Manubri', 'Picco di contrazione in estensione completa.'),
  SeedExerciseDef('Pushdown unilaterale al cavo', MuscleGroups.tricipiti, 'Cavi', 'Corregge asimmetrie tra braccio destro e sinistro.'),
  SeedExerciseDef('Piegamenti a diamante', MuscleGroups.tricipiti, 'Corpo libero', 'Mani ravvicinate a triangolo sotto lo sterno.'),

  // ===================== GAMBE (16) =====================
  SeedExerciseDef('Squat con bilanciere', MuscleGroups.gambe, 'Bilanciere', 'Esercizio base per quadricipiti, glutei e core.'),
  SeedExerciseDef('Front squat con bilanciere', MuscleGroups.gambe, 'Bilanciere', 'Maggiore enfasi sui quadricipiti e busto eretto.'),
  SeedExerciseDef('Hack squat alla macchina', MuscleGroups.gambe, 'Macchina', 'Stabilità elevata per spingere i quadricipiti.'),
  SeedExerciseDef('Goblet squat con manubrio', MuscleGroups.gambe, 'Manubri', 'Ottimo per apprendimento tecnica e profondità.'),
  SeedExerciseDef('Leg press 45 gradi', MuscleGroups.gambe, 'Macchina', 'Alto carico sulle gambe senza gravare sulla schiena.'),
  SeedExerciseDef('Leg press orizzontale', MuscleGroups.gambe, 'Macchina', 'Spinta controllata per arti inferiori.'),
  SeedExerciseDef('Affondi bulgari con manubri', MuscleGroups.gambe, 'Manubri', 'Unilaterale intenso per quadricipiti e glutei.'),
  SeedExerciseDef('Affondi in camminata con manubri', MuscleGroups.gambe, 'Manubri', 'Lavoro dinamico su stabilità e gambe.'),
  SeedExerciseDef('Affondi posteriori al multipower', MuscleGroups.gambe, 'Multipower', 'Controllo elevato e focus su quadricipiti/glutei.'),
  SeedExerciseDef('Leg extension', MuscleGroups.gambe, 'Macchina', 'Isolamento completo del quadricipite.'),
  SeedExerciseDef('Stacco rumeno con bilanciere', MuscleGroups.gambe, 'Bilanciere', 'Catena posteriore: femorali e glutei.'),
  SeedExerciseDef('Stacco rumeno con manubri', MuscleGroups.gambe, 'Manubri', 'Variante pratica per femorali e glutei.'),
  SeedExerciseDef('Leg curl sdraiato', MuscleGroups.gambe, 'Macchina', 'Isolamento dei muscoli ischiocrurali.'),
  SeedExerciseDef('Leg curl seduto', MuscleGroups.gambe, 'Macchina', 'Femorali in maggiore allungamento all\'anca.'),
  SeedExerciseDef('Calf raise in piedi', MuscleGroups.gambe, 'Macchina', 'Focus sul gastrocnemio.'),
  SeedExerciseDef('Calf raise seduto', MuscleGroups.gambe, 'Macchina', 'Focus sul soleo.'),

  // ===================== GLUTEI (9) =====================
  SeedExerciseDef('Hip thrust con bilanciere', MuscleGroups.glutei, 'Bilanciere', 'Esercizio principe per forza e volume glutei.'),
  SeedExerciseDef('Hip thrust alla macchina', MuscleGroups.glutei, 'Macchina', 'Setup rapido per estensione d\'anca.'),
  SeedExerciseDef('Ponte glutei a terra', MuscleGroups.glutei, 'Corpo libero', 'Attivazione o variante zavorrata.'),
  SeedExerciseDef('Slanci posteriori ai cavi', MuscleGroups.glutei, 'Cavi', 'Estensione anca con cavigliera.'),
  SeedExerciseDef('Abductor machine', MuscleGroups.glutei, 'Macchina', 'Focus su medio e piccolo gluteo.'),
  SeedExerciseDef('Adductor machine', MuscleGroups.glutei, 'Macchina', 'Rinforzo adduttori interno coscia.'),
  SeedExerciseDef('Step up su box con manubri', MuscleGroups.glutei, 'Manubri', 'Spinta unilaterale dal tallone.'),
  SeedExerciseDef('Kettlebell swing', MuscleGroups.glutei, 'Kettlebell', 'Estensione esplosiva dell\'anca.'),
  SeedExerciseDef('Sumo squat con manubrio', MuscleGroups.glutei, 'Manubri', 'Stance ampio per glutei e adduttori.'),

  // ===================== ADDOME (11) =====================
  SeedExerciseDef('Plank isometrico', MuscleGroups.addome, 'Corpo libero', 'Stabilità profonda del core.'),
  SeedExerciseDef('Side plank', MuscleGroups.addome, 'Corpo libero', 'Stabilità degli obliqui e quadrato dei lombi.'),
  SeedExerciseDef('Crunch a terra', MuscleGroups.addome, 'Corpo libero', 'Flessione controllata del tronco.'),
  SeedExerciseDef('Crunch ai cavi', MuscleGroups.addome, 'Cavi', 'Sovraccarico progressivo per retto addominale.'),
  SeedExerciseDef('Crunch alla macchina', MuscleGroups.addome, 'Macchina', 'Flessione guidata con carico regolabile.'),
  SeedExerciseDef('Leg raise alla sbarra', MuscleGroups.addome, 'Corpo libero', 'Sollevamento gambe con retroversione bacino.'),
  SeedExerciseDef('Leg raise alle parallele', MuscleGroups.addome, 'Corpo libero', 'Variante con supporto avambracci.'),
  SeedExerciseDef('Ab wheel rollout', MuscleGroups.addome, 'Altro', 'Anti-estensione intensa del core.'),
  SeedExerciseDef('Russian twist con disco', MuscleGroups.addome, 'Altro', 'Rotazione controllata per obliqui.'),
  SeedExerciseDef('Bicycle crunch', MuscleGroups.addome, 'Corpo libero', 'Lavoro dinamico su retto e obliqui.'),
  SeedExerciseDef('Pallof press ai cavi', MuscleGroups.addome, 'Cavi', 'Anti-rotazione del tronco.'),

  // ===================== CARDIO (8) =====================
  SeedExerciseDef('Corsa su tapis roulant', MuscleGroups.cardio, 'Cardio', 'Camminata in salita o corsa costante/HIIT.'),
  SeedExerciseDef('Cyclette', MuscleGroups.cardio, 'Cardio', 'Cardio a basso impatto articolare.'),
  SeedExerciseDef('Ellittica', MuscleGroups.cardio, 'Cardio', 'Lavoro aerobico full body fluido.'),
  SeedExerciseDef('Vogatore (Rowing Erg)', MuscleGroups.cardio, 'Cardio', 'Cardio ad alto dispendio con schiena e gambe.'),
  SeedExerciseDef('StairMaster (Scale)', MuscleGroups.cardio, 'Cardio', 'Salita continua per resistenza e glutei.'),
  SeedExerciseDef('Assault Bike', MuscleGroups.cardio, 'Cardio', 'Ideale per intervalli ad alta intensità.'),
  SeedExerciseDef('Salto con la corda', MuscleGroups.cardio, 'Cardio', 'Coordinazione e condizionamento rapido.'),
  SeedExerciseDef('Camminata in pendenza', MuscleGroups.cardio, 'Cardio', 'Ottima per recupero attivo e consumo calorico.'),
];

/// Template schede precompilate (Push/Pull/Legs, Full Body, Upper/Lower).
const List<SeedRoutineTemplateDef> seedRoutineTemplates = [
  SeedRoutineTemplateDef(
    name: 'Push — Spinta',
    description: 'Petto, spalle anteriori/laterali e tricipiti (parte di Push/Pull/Legs).',
    weekdays: [1, 4],
    exercises: [
      SeedRoutineExerciseDef('Panca piana con bilanciere', 4, '6-8', 150),
      SeedRoutineExerciseDef('Panca inclinata con manubri', 3, '8-10', 120),
      SeedRoutineExerciseDef('Croci ai cavi alti', 3, '12-15', 75),
      SeedRoutineExerciseDef('Military press con bilanciere', 3, '6-8', 120),
      SeedRoutineExerciseDef('Alzate laterali con manubri', 4, '12-15', 60),
      SeedRoutineExerciseDef('Pushdown tricipiti ai cavi con corda', 3, '10-12', 75),
    ],
  ),
  SeedRoutineTemplateDef(
    name: 'Pull — Tirata',
    description: 'Schiena, deltoidi posteriori e bicipiti (parte di Push/Pull/Legs).',
    weekdays: [2, 5],
    exercises: [
      SeedRoutineExerciseDef('Trazioni alla sbarra presa prona', 4, '6-10', 120),
      SeedRoutineExerciseDef('Rematore con bilanciere', 4, '8-10', 120),
      SeedRoutineExerciseDef('Lat machine presa larga', 3, '10-12', 90),
      SeedRoutineExerciseDef('Pulley basso seduto', 3, '10-12', 90),
      SeedRoutineExerciseDef('Face pull ai cavi', 3, '15', 60),
      SeedRoutineExerciseDef('Curl bilanciere EZ', 3, '10-12', 75),
    ],
  ),
  SeedRoutineTemplateDef(
    name: 'Legs — Gambe e Glutei',
    description: 'Quadricipiti, femorali, glutei e polpacci (parte di Push/Pull/Legs).',
    weekdays: [3, 6],
    exercises: [
      SeedRoutineExerciseDef('Squat con bilanciere', 4, '6-8', 150),
      SeedRoutineExerciseDef('Stacco rumeno con bilanciere', 4, '8-10', 120),
      SeedRoutineExerciseDef('Leg press 45 gradi', 3, '10-12', 120),
      SeedRoutineExerciseDef('Leg curl sdraiato', 3, '10-12', 75),
      SeedRoutineExerciseDef('Hip thrust con bilanciere', 3, '8-12', 120),
      SeedRoutineExerciseDef('Calf raise in piedi', 4, '12-15', 60),
    ],
  ),
  SeedRoutineTemplateDef(
    name: 'Full Body Bilanciata',
    description: 'Scheda completa su 3 giorni settimanali ideale per progressione costante.',
    weekdays: [1, 3, 5],
    exercises: [
      SeedRoutineExerciseDef('Squat con bilanciere', 4, '6-8', 150),
      SeedRoutineExerciseDef('Panca piana con bilanciere', 4, '6-8', 120),
      SeedRoutineExerciseDef('Lat machine presa larga', 3, '8-12', 90),
      SeedRoutineExerciseDef('Lento avanti con manubri', 3, '8-10', 90),
      SeedRoutineExerciseDef('Stacco rumeno con manubri', 3, '10-12', 90),
      SeedRoutineExerciseDef('Plank isometrico', 3, '45-60s', 60),
    ],
  ),
  SeedRoutineTemplateDef(
    name: 'Upper Body',
    description: 'Allenamento completo della parte superiore (split Upper/Lower 4 giorni).',
    weekdays: [1, 4],
    exercises: [
      SeedRoutineExerciseDef('Panca piana con bilanciere', 4, '6-8', 150),
      SeedRoutineExerciseDef('Rematore con manubrio singolo', 4, '8-10', 90),
      SeedRoutineExerciseDef('Lento avanti con manubri', 3, '8-10', 90),
      SeedRoutineExerciseDef('Lat machine presa inversa', 3, '10-12', 90),
      SeedRoutineExerciseDef('Alzate laterali ai cavi', 3, '12-15', 60),
      SeedRoutineExerciseDef('Curl manubri alternato', 3, '10-12', 60),
      SeedRoutineExerciseDef('French press con bilanciere EZ', 3, '10-12', 60),
    ],
  ),
  SeedRoutineTemplateDef(
    name: 'Lower Body',
    description: 'Allenamento completo della parte inferiore e core (split Upper/Lower 4 giorni).',
    weekdays: [2, 5],
    exercises: [
      SeedRoutineExerciseDef('Squat con bilanciere', 4, '6-8', 150),
      SeedRoutineExerciseDef('Stacco da terra classico', 3, '5', 180),
      SeedRoutineExerciseDef('Affondi bulgari con manubri', 3, '10', 90),
      SeedRoutineExerciseDef('Leg extension', 3, '12-15', 75),
      SeedRoutineExerciseDef('Leg curl seduto', 3, '10-12', 75),
      SeedRoutineExerciseDef('Crunch ai cavi', 3, '12-15', 60),
    ],
  ),
];