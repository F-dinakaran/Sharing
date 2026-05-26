import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
// DEPENDENCIES TO ADD TO pubspec.yaml:
//
// dependencies:
//   health: ^10.2.0          # HealthKit / Health Connect polling
//   flutter_blue_plus: ^1.31.0  # BLE streaming (Polar, Wahoo etc.)
//   permission_handler: ^11.3.0
//
// iOS — add to Info.plist:
//   NSHealthShareUsageDescription
//   NSBluetoothAlwaysUsageDescription
//
// Android — add to AndroidManifest.xml:
//   BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACTIVITY_RECOGNITION
// ─────────────────────────────────────────────────────────────


class Fitness extends StatelessWidget {
  const Fitness({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cardiac Rehab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E5496)),
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),
    );
  }
}

// ── DATA MODELS ──────────────────────────────────────────────

class UserProfile {
  final String name;
  final int age;
  final int restingHR;
  final int phase;
  final bool hasDiabetes;
  final bool hasCOPD;
  final bool hasObesity;
  final bool isPostSternotomy;
  final bool hasHeartFailure;
  final bool hasLowerLimbIssue;
  final bool hasUpperLimbIssue;
  final bool hasBackProblem;
  final bool hasBalanceIssue;
  final bool likesWalking;
  final bool likesCycling;
  final bool likesSwimming;

  UserProfile({
    required this.name,
    required this.age,
    required this.restingHR,
    required this.phase,
    required this.hasDiabetes,
    required this.hasCOPD,
    required this.hasObesity,
    required this.isPostSternotomy,
    required this.hasHeartFailure,
    required this.hasLowerLimbIssue,
    required this.hasUpperLimbIssue,
    required this.hasBackProblem,
    required this.hasBalanceIssue,
    required this.likesWalking,
    required this.likesCycling,
    required this.likesSwimming,
  });

  int get targetHRLow => (restingHR + 0.40 * (220 - age - restingHR)).round();
  int get targetHRHigh =>
      // Heart failure patients capped lower
      hasHeartFailure
      ? (restingHR + 0.50 * (220 - age - restingHR)).round()
      : (restingHR + 0.70 * (220 - age - restingHR)).round();

  String get rpeRange {
    if (phase == 1) return '2–3';
    if (phase == 2) return '3–5';
    if (phase == 3) return '4–6';
    return '3–7';
  }

  int get sessionsPerWeek {
    if (phase == 1) return 7;
    if (phase == 2) return 3;
    if (phase == 3) return 4;
    return 5;
  }

  int get sessionDuration {
    if (phase == 1) return 15;
    if (phase == 2) return 30;
    if (phase == 3) return 45;
    return 55;
  }

  bool get isElderly => age >= 65;
  bool get isVeryElderly => age >= 75;
}

class Exercise {
  final String name;
  final String category;
  final String variation;
  final String keyCue;
  final String duration;

  Exercise({
    required this.name,
    required this.category,
    required this.variation,
    required this.keyCue,
    required this.duration,
  });
}

class DayPlan {
  final String dayName;
  final bool isRest;
  final String sessionFocus;
  final List<Exercise> warmUp;
  final List<Exercise> mainSession;
  final List<Exercise> coolDown;

  DayPlan({
    required this.dayName,
    required this.isRest,
    this.sessionFocus = '',
    this.warmUp = const [],
    this.mainSession = const [],
    this.coolDown = const [],
  });

  List<Exercise> get allExercises => [...warmUp, ...mainSession, ...coolDown];
}

class SessionLog {
  final String dayName;
  final DateTime completedAt;
  final int rpe;
  final String note;
  final Duration sessionDuration;
  final int? avgHR;
  final int? timeInZoneSeconds;
  final int? peakHR;

  SessionLog({
    required this.dayName,
    required this.completedAt,
    required this.rpe,
    required this.note,
    this.sessionDuration = Duration.zero,
    this.avgHR,
    this.timeInZoneSeconds,
    this.peakHR,
  });
}

// ── HEART RATE SERVICE ────────────────────────────────────────
//
// This service abstracts HealthKit polling vs BLE streaming.
// In production, swap the _simulatedHRStream() body with real
// health package calls or flutter_blue_plus characteristic reads.

enum HRSourceType { healthKit, ble, none }

class HRReading {
  final int bpm;
  final DateTime timestamp;
  final HRSourceType source;

  HRReading({required this.bpm, required this.timestamp, required this.source});
}

class HRZone {
  final String label;
  final Color color;
  final IconData icon;

  const HRZone({required this.label, required this.color, required this.icon});
}

class HeartRateService {
  final UserProfile profile;
  HRSourceType activeSource = HRSourceType.none;

  HeartRateService(this.profile);

  // ── Public stream — swap internals when integrating real packages ──

  Stream<HRReading> heartRateStream() async* {
    // 1. Try BLE (chest strap) first
    // In production:
    //   final device = await _findConnectedBLEDevice();
    //   if (device != null) { yield* _streamFromBLE(device); return; }

    // 2. Fall back to HealthKit polling
    // In production:
    //   yield* _pollHealthKit();

    // 3. For now: simulate realistic HR data so the UI is fully functional
    activeSource = HRSourceType.healthKit;
    yield* _simulatedHRStream();
  }

  // ── HealthKit polling stub (production) ──
  //
  // Stream<HRReading> _pollHealthKit() async* {
  //   final health = Health();
  //   await health.requestAuthorization([HealthDataType.HEART_RATE]);
  //   while (true) {
  //     await Future.delayed(const Duration(seconds: 5));
  //     final samples = await health.getHealthDataFromTypes(
  //       startTime: DateTime.now().subtract(const Duration(seconds: 30)),
  //       endTime: DateTime.now(),
  //       types: [HealthDataType.HEART_RATE],
  //     );
  //     if (samples.isNotEmpty) {
  //       final hr = (samples.last.value as NumericHealthValue)
  //           .numericValue.round();
  //       yield HRReading(
  //         bpm: hr,
  //         timestamp: DateTime.now(),
  //         source: HRSourceType.healthKit,
  //       );
  //     }
  //   }
  // }

  // ── BLE streaming stub (production) ──
  //
  // Stream<HRReading> _streamFromBLE(BluetoothDevice device) async* {
  //   final services = await device.discoverServices();
  //   final hrService = services.firstWhere(
  //     (s) => s.uuid.toString() == '0000180d-0000-1000-8000-00805f9b34fb',
  //   );
  //   final hrChar = hrService.characteristics.firstWhere(
  //     (c) => c.uuid.toString() == '00002a37-0000-1000-8000-00805f9b34fb',
  //   );
  //   await hrChar.setNotifyValue(true);
  //   await for (final value in hrChar.onValueReceived) {
  //     final hr = value[1]; // Standard HR GATT format
  //     yield HRReading(
  //       bpm: hr,
  //       timestamp: DateTime.now(),
  //       source: HRSourceType.ble,
  //     );
  //   }
  // }

  // ── Simulator — realistic warm-up curve then steady state ──
  Stream<HRReading> _simulatedHRStream() async* {
    final rng = Random();
    int current = profile.restingHR;
    final target =
        profile.targetHRLow + (profile.targetHRHigh - profile.targetHRLow) ~/ 2;
    int tick = 0;

    while (true) {
      await Future.delayed(const Duration(seconds: 3));
      tick++;
      // Ramp up over first 20 ticks (~1 min), then hover around target ±5
      if (tick < 20) {
        current = (current + (target - current) * 0.08).round();
      } else {
        current = (target + rng.nextInt(11) - 5).clamp(
          profile.restingHR,
          profile.targetHRHigh + 20,
        );
      }
      yield HRReading(
        bpm: current,
        timestamp: DateTime.now(),
        source: HRSourceType.healthKit,
      );
    }
  }

  HRZone getZone(int bpm) {
    if (bpm < profile.targetHRLow) {
      return const HRZone(
        label: 'Below zone',
        color: Color(0xFF2196F3),
        icon: Icons.arrow_downward,
      );
    } else if (bpm <= profile.targetHRHigh) {
      return const HRZone(
        label: 'In zone',
        color: Color(0xFF4CAF50),
        icon: Icons.check_circle,
      );
    } else if (bpm <= profile.targetHRHigh + 10) {
      return const HRZone(
        label: 'Above zone',
        color: Color(0xFFFF9800),
        icon: Icons.warning_rounded,
      );
    } else {
      return const HRZone(
        label: 'Too high — slow down',
        color: Color(0xFFF44336),
        icon: Icons.dangerous,
      );
    }
  }
}

// ── EXERCISE PLANNER ──────────────────────────────────────────

class ExercisePlanner {
  final UserProfile profile;
  ExercisePlanner(this.profile);

  List<DayPlan> generateWeek() {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    if (profile.phase == 1) {
      return List.generate(
        7,
        (i) => DayPlan(
          dayName: days[i],
          isRest: false,
          sessionFocus: i % 2 == 0
              ? 'Mobility & gentle aerobic'
              : 'Breathing & gentle movement',
          warmUp: _buildWarmUp(),
          mainSession: _buildPhase1Session(i),
          coolDown: _buildCoolDown(),
        ),
      );
    }

    final sessionDays = _pickSessionDays();
    final focuses = _pickSessionFocuses();

    return List.generate(7, (i) {
      final sessionIndex = sessionDays.indexOf(i);
      if (sessionIndex != -1) {
        return DayPlan(
          dayName: days[i],
          isRest: false,
          sessionFocus: focuses[sessionIndex],
          warmUp: _buildWarmUp(),
          mainSession: _buildVariedMainSession(focuses[sessionIndex]),
          coolDown: _buildCoolDown(),
        );
      }
      return DayPlan(dayName: days[i], isRest: true);
    });
  }

  List<int> _pickSessionDays() {
    if (profile.phase == 2) return [0, 2, 4];
    if (profile.phase == 3) return [0, 1, 3, 5];
    return [0, 1, 2, 4, 5];
  }

  List<String> _pickSessionFocuses() {
    if (profile.phase == 2) {
      return ['Aerobic base', 'Aerobic + light resistance', 'Aerobic base'];
    }
    if (profile.phase == 3) {
      return [
        'Aerobic endurance',
        'Resistance focus',
        'Aerobic + resistance',
        'Active recovery',
      ];
    }
    return [
      'Aerobic endurance',
      'Resistance focus',
      'Aerobic intervals',
      'Aerobic + resistance',
      'Active recovery',
    ];
  }

  List<Exercise> _buildPhase1Session(int dayIndex) {
    if (dayIndex % 2 == 0) {
      return [
        Exercise(
          name: 'Supervised corridor walk',
          category: 'Aerobic',
          variation: 'Flat indoor surface, very short distance',
          keyCue: 'Conversational pace. Stop at any discomfort or dizziness.',
          duration: '5–10 min',
        ),
        Exercise(
          name: 'Sit-to-stand',
          category: 'Resistance — Lower body',
          variation: 'High chair, hands pushing off armrests',
          keyCue: 'Exhale on standing. Lead with chest, not head.',
          duration: '1 set × 5–10 reps',
        ),
      ];
    } else {
      return [
        Exercise(
          name: 'Seated leg raises',
          category: 'Gentle movement',
          variation: 'Seated, slow alternating leg lifts',
          keyCue: 'Breathe continuously. Stop if dizzy.',
          duration: '1 set × 10 reps',
        ),
        Exercise(
          name: 'Seated belly breathing + brace',
          category: 'Breathing & core',
          variation: 'Gentle abdominal engagement on exhale, seated',
          keyCue: 'Never hold breath. Gentle engagement only.',
          duration: '5 min',
        ),
      ];
    }
  }

  List<Exercise> _buildVariedMainSession(String focus) {
    final exercises = <Exercise>[];
    switch (focus) {
      case 'Aerobic base':
      case 'Aerobic endurance':
        exercises.add(_pickAerobicExercise(intensity: 'moderate'));
        break;
      case 'Aerobic intervals':
        exercises.add(_pickAerobicExercise(intensity: 'intervals'));
        break;
      case 'Resistance focus':
        exercises.addAll(_pickResistanceExercises());
        break;
      // FIX: consolidated duplicate cases into a single fall-through block.
      // Previously 'Aerobic + light resistance' appeared twice; the second
      // occurrence was dead code because the first case already matched and
      // broke out of the switch.
      case 'Aerobic + light resistance':
      case 'Aerobic + resistance':
        exercises.add(_pickAerobicExercise(intensity: 'moderate'));
        exercises.addAll(_pickResistanceExercises());
        break;
      case 'Active recovery':
        exercises.add(
          Exercise(
            name: 'Light walking or gentle cycling',
            category: 'Active recovery',
            variation: 'Very easy pace, no intensity targets today',
            keyCue:
                'RPE should feel like 1–2. This is movement, not a workout.',
            duration: '20–30 min',
          ),
        );
        exercises.add(
          Exercise(
            name: 'Full body stretching',
            category: 'Flexibility',
            variation: 'Gentle held stretches, all major muscle groups',
            keyCue: 'Hold each stretch 20–30 seconds. Never force or bounce.',
            duration: '10 min',
          ),
        );
        break;
    }
    return exercises;
  }

  Exercise _pickAerobicExercise({required String intensity}) {
    final duration = '${profile.sessionDuration} min';

    if (profile.isVeryElderly) {
      if (profile.likesCycling) {
        return Exercise(
          name: 'Recumbent cycling',
          category: 'Aerobic',
          variation: 'Seat-back supported bike, very low resistance',
          keyCue:
              'Cadence 50–60 rpm. RPE target: ${profile.rpeRange}. No intervals or inclines.',
          duration: duration,
        );
      }
      return Exercise(
        name: 'Flat walking',
        category: 'Aerobic',
        variation: 'Slow to moderate pace, completely flat surface',
        keyCue:
            'Conversational pace at all times. RPE target: ${profile.rpeRange}. Stop at any discomfort.',
        duration: duration,
      );
    }

    if (profile.isElderly) {
      if (profile.likesCycling) {
        return Exercise(
          name: 'Recumbent or upright stationary cycling',
          category: 'Aerobic',
          variation: 'Low to moderate resistance, steady pace',
          keyCue:
              'Cadence 50–70 rpm. RPE target: ${profile.rpeRange}. No interval work.',
          duration: duration,
        );
      }
      if (profile.likesSwimming && profile.phase >= 3) {
        return Exercise(
          name: 'Water aerobics or slow lap swimming',
          category: 'Aerobic',
          variation: 'Gentle pace, shallow pool preferred',
          keyCue:
              'Inform lifeguard of cardiac history. RPE target: ${profile.rpeRange}.',
          duration: duration,
        );
      }
      return Exercise(
        name: 'Brisk walking',
        category: 'Aerobic',
        variation: 'Flat route, moderate pace — no inclines or jogging',
        keyCue:
            'Conversational pace. RPE target: ${profile.rpeRange}. Target HR: ${profile.targetHRLow}–${profile.targetHRHigh} bpm.',
        duration: duration,
      );
    }

    if (profile.hasLowerLimbIssue && !profile.likesCycling) {
      return Exercise(
        name: 'Seated upper body ergometer',
        category: 'Aerobic',
        variation: 'Arm cycling at low resistance, seated',
        keyCue:
            'Keep resistance low. Exhale on each push. Stop if shoulder discomfort.',
        duration: duration,
      );
    }

    if (profile.hasObesity || (profile.hasCOPD && profile.phase <= 2)) {
      if (profile.likesSwimming) {
        return Exercise(
          name: 'Water walking',
          category: 'Aerobic',
          variation: 'Shallow pool, slow pace',
          keyCue:
              'Inform lifeguard of cardiac history. Water masks effort — monitor RPE carefully.',
          duration: profile.hasCOPD ? '10–15 min with rest breaks' : duration,
        );
      }
      return Exercise(
        name: 'Recumbent cycling',
        category: 'Aerobic',
        variation: 'Seat-back supported bike, low resistance',
        keyCue: 'Cadence 50–70 rpm. Keep resistance smooth and controlled.',
        duration: duration,
      );
    }

    if (profile.hasHeartFailure) {
      return Exercise(
        name: 'Interval walking',
        category: 'Aerobic',
        variation: '5 min walk / 2 min seated rest, repeat',
        keyCue:
            'RPE must not exceed 5. Stop immediately if breathless at rest.',
        duration: duration,
      );
    }

    if (profile.hasCOPD) {
      return Exercise(
        name: 'Walking with rest breaks',
        category: 'Aerobic',
        variation: '5–10 min walking bouts with planned seated rest',
        keyCue:
            'Monitor breathlessness separately using the 0–10 Borg dyspnoea scale.',
        duration: duration,
      );
    }

    if (intensity == 'intervals' && profile.phase >= 3) {
      if (profile.likesCycling) {
        return Exercise(
          name: 'Cycling intervals',
          category: 'Aerobic',
          variation: '30s higher effort / 90s easy, repeat',
          keyCue:
              'Higher effort still within RPE zone — not maximal. Target HR: ${profile.targetHRLow}–${profile.targetHRHigh} bpm.',
          duration: duration,
        );
      }
      return Exercise(
        name: 'Walk-jog intervals',
        category: 'Aerobic',
        variation: '1 min jog / 4 min walk, gradually increase jog ratio',
        keyCue:
            'Never exceed RPE ${profile.rpeRange} during jog. Conversational pace during walk.',
        duration: duration,
      );
    }

    if (profile.likesSwimming && profile.phase >= 3) {
      return Exercise(
        name: 'Lap swimming',
        category: 'Aerobic',
        variation: 'Slow controlled laps',
        keyCue: 'No diving or breath-holding. Inform lifeguard.',
        duration: duration,
      );
    }

    if (profile.likesCycling) {
      if (profile.phase >= 3) {
        return Exercise(
          name: 'Upright stationary cycling',
          category: 'Aerobic',
          variation: 'Steady pace, moderate resistance',
          keyCue:
              'Cadence 50–70 rpm. Target HR zone: ${profile.targetHRLow}–${profile.targetHRHigh} bpm.',
          duration: duration,
        );
      }
      return Exercise(
        name: 'Recumbent cycling',
        category: 'Aerobic',
        variation: 'Seat-back supported, low resistance',
        keyCue: 'Cadence 50–70 rpm. RPE target: ${profile.rpeRange}.',
        duration: duration,
      );
    }

    if (profile.phase >= 3) {
      return Exercise(
        name: 'Brisk outdoor walk',
        category: 'Aerobic',
        variation: 'Flat to slight incline route',
        keyCue:
            'Target HR zone: ${profile.targetHRLow}–${profile.targetHRHigh} bpm. Conversational pace.',
        duration: duration,
      );
    }

    return Exercise(
      name: 'Treadmill walking',
      category: 'Aerobic',
      variation: 'Flat, moderate pace',
      keyCue: 'Do not hold the rails. RPE target: ${profile.rpeRange}.',
      duration: duration,
    );
  }

  List<Exercise> _pickResistanceExercises() {
    final exercises = <Exercise>[];

    if (!profile.hasLowerLimbIssue) {
      if (profile.phase == 2 || profile.isElderly || profile.hasHeartFailure) {
        exercises.add(
          Exercise(
            name: 'Sit-to-stand',
            category: 'Resistance — Lower body',
            variation: profile.isElderly || profile.phase == 2
                ? 'High chair, hands pushing off armrests'
                : 'Standard chair, hands on thighs',
            keyCue:
                'Exhale on standing. Lead with chest, not head. 1–2 sets of 10–15 reps.',
            duration: '1–2 sets × 10–15 reps',
          ),
        );
      } else {
        exercises.add(
          Exercise(
            name: 'Leg press',
            category: 'Resistance — Lower body',
            variation: profile.phase >= 3
                ? 'Moderate load, full range of motion'
                : 'Minimal load, partial range',
            keyCue:
                'Exhale on push. Do not lock knees. Keep lower back against seat.',
            duration: '2 sets × 12–15 reps',
          ),
        );
      }
      exercises.add(
        Exercise(
          name: 'Calf raises',
          category: 'Resistance — Lower body',
          variation: profile.phase <= 2 || profile.isElderly
              ? 'Seated, feet flat on floor'
              : 'Standing with wall support',
          keyCue:
              'Slow and controlled, full range heel to toe. Avoid bouncing.',
          duration: '2 sets × 15 reps',
        ),
      );
    } else {
      exercises.add(
        Exercise(
          name: 'Seated leg extensions (pain-free range only)',
          category: 'Resistance — Lower body',
          variation: 'Move only within a comfortable, pain-free range',
          keyCue:
              'Never push through pain. Exhale on extension. Inform physiotherapist of your limitation.',
          duration: '1 set × 8–10 reps',
        ),
      );
    }

    if (!profile.isPostSternotomy || profile.phase >= 3) {
      if (!profile.hasUpperLimbIssue && !profile.hasBackProblem) {
        exercises.add(
          Exercise(
            name: 'Seated row',
            category: 'Resistance — Upper body',
            variation: profile.phase == 2 || profile.isPostSternotomy
                ? 'Theraband seated row'
                : 'Cable row machine, light weight',
            keyCue: 'Pull elbows back. Exhale on the pull. Keep spine neutral.',
            duration: '2 sets × 12–15 reps',
          ),
        );
      } else if (profile.hasUpperLimbIssue) {
        exercises.add(
          Exercise(
            name: 'Single arm seated row (unaffected side)',
            category: 'Resistance — Upper body',
            variation: 'Theraband, one arm only on unaffected side',
            keyCue:
                'Work only the unaffected arm. Keep spine neutral. Exhale on pull.',
            duration: '2 sets × 12–15 reps',
          ),
        );
      }
    }

    if (!profile.hasBackProblem) {
      exercises.add(
        Exercise(
          name: profile.phase <= 2
              ? 'Seated belly breathing + brace'
              : 'Seated marching',
          category: 'Resistance — Core',
          variation: profile.phase <= 2
              ? 'Gentle abdominal engagement on exhale, seated'
              : 'Alternating knee lifts, seated upright',
          keyCue: 'Never hold your breath. Gentle engagement only.',
          duration: '1–2 sets × 10–15 reps',
        ),
      );
    } else {
      exercises.add(
        Exercise(
          name: 'Seated diaphragmatic breathing',
          category: 'Breathing & core',
          variation: 'Gentle belly breathing only, no spinal loading',
          keyCue:
              'No forward bending or rotation. Focus purely on breath control.',
          duration: '5 min',
        ),
      );
    }

    return exercises;
  }

  List<Exercise> _buildWarmUp() {
    return [
      Exercise(
        name: 'Gentle warm-up',
        category: 'Warm-up',
        variation: profile.hasObesity || profile.hasCOPD
            ? 'Slow indoor walk, flat surface'
            : profile.hasLowerLimbIssue
            ? 'Seated arm movements and gentle upper body warm-up'
            : profile.isVeryElderly
            ? 'Slow flat walk or seated arm swings'
            : 'Slow walk or easy cycling',
        keyCue: 'Aim for RPE 1–2 only. This is preparation, not exercise.',
        duration: '5–10 min',
      ),
      Exercise(
        name: 'Dynamic stretching',
        category: 'Warm-up',
        variation: profile.hasBalanceIssue || profile.isVeryElderly
            ? 'All movements seated — shoulder rolls, neck tilts, ankle circles'
            : 'Shoulder rolls, neck tilts, ankle circles — seated if needed',
        keyCue: 'Slow and deliberate, never forced',
        duration: '3–5 min',
      ),
    ];
  }

  List<Exercise> _buildCoolDown() {
    final exercises = <Exercise>[];

    exercises.add(
      Exercise(
        name: profile.hasCOPD
            ? 'Pursed lip breathing'
            : 'Diaphragmatic breathing',
        category: 'Cool-down',
        variation: profile.hasCOPD
            ? 'Slow exhale through pursed lips'
            : 'Seated, one hand on chest, one on belly',
        keyCue: profile.hasCOPD
            ? 'Primary cool-down tool for breathlessness.'
            : 'Belly hand should rise more than chest hand.',
        duration: '3–5 min',
      ),
    );

    if (!profile.hasLowerLimbIssue) {
      exercises.add(
        Exercise(
          name: 'Hamstring stretch',
          category: 'Cool-down',
          variation: profile.phase <= 2 || profile.isElderly
              ? 'Seated, leg extended on chair, gentle lean forward'
              : 'Standing, foot on low step, gentle lean',
          keyCue:
              'Mild tension only, never pain. Hold 20–30 seconds each side.',
          duration: '20–30 sec each side',
        ),
      );

      exercises.add(
        Exercise(
          name: 'Calf stretch',
          category: 'Cool-down',
          variation: profile.phase <= 2 || profile.isElderly
              ? 'Seated, towel around foot, gentle pull'
              : 'Standing, hands on wall, step back',
          keyCue: 'Back heel flat on floor. Hold 20–30 seconds each side.',
          duration: '20–30 sec each side',
        ),
      );
    }

    if (!profile.isPostSternotomy || profile.phase >= 3) {
      if (!profile.hasUpperLimbIssue) {
        exercises.add(
          Exercise(
            name: 'Chest opener',
            category: 'Cool-down',
            variation: profile.phase <= 2 || profile.isElderly
                ? 'Seated, hands clasped behind back, gentle lift'
                : 'Standing doorway stretch',
            keyCue:
                'Never force. Hold 20–30 seconds. Breathe continuously throughout.',
            duration: '20–30 sec',
          ),
        );
      }
    }

    if (!profile.hasBackProblem) {
      exercises.add(
        Exercise(
          name: 'Hip flexor stretch',
          category: 'Cool-down',
          variation: profile.phase <= 2 || profile.isElderly
              ? 'Seated at edge of chair, one leg extended back'
              : 'Standing shallow lunge, hands on thigh',
          keyCue: 'Keep torso upright. Hold 20–30 seconds each side.',
          duration: '20–30 sec each side',
        ),
      );
    }

    return exercises;
  }
}

// ── ONBOARDING SCREEN ─────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _restingHRController = TextEditingController();
  int _selectedPhase = 2;
  bool _hasDiabetes = false;
  bool _hasCOPD = false;
  bool _hasObesity = false;
  bool _isPostSternotomy = false;
  bool _hasHeartFailure = false;
  bool _hasLowerLimbIssue = false;
  bool _hasUpperLimbIssue = false;
  bool _hasBackProblem = false;
  bool _hasBalanceIssue = false;
  bool _likesWalking = false;
  bool _likesCycling = false;
  bool _likesSwimming = false;
  bool _showHRWarning = false;

  void _checkHR(String value) {
    final hr = int.tryParse(value);
    setState(() {
      _showHRWarning = hr != null && (hr < 40 || hr > 120);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E5496),
        title: const Text(
          'Your Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionTitle('Basic Information'),
            _inputField(_nameController, 'Full name', Icons.person),
            const SizedBox(height: 12),
            _inputField(_ageController, 'Age', Icons.cake, isNumber: true),
            const SizedBox(height: 12),
            TextFormField(
              controller: _restingHRController,
              keyboardType: TextInputType.number,
              onChanged: _checkHR,
              decoration: InputDecoration(
                labelText: 'Resting heart rate (bpm)',
                prefixIcon: const Icon(
                  Icons.favorite,
                  color: Color(0xFF2E5496),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty)
                  return 'Please fill in this field';
                final hr = int.tryParse(val);
                if (hr == null) return 'Please enter a valid number';
                if (hr < 20 || hr > 200)
                  return 'Please enter a realistic heart rate value';
                return null;
              },
            ),
            if (_showHRWarning)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This resting HR seems unusual. Please double-check your reading. If correct, make sure your clinical team is aware before starting exercise.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _sectionTitle('Rehabilitation Phase'),
            _phaseSelector(),
            const SizedBox(height: 24),
            _sectionTitle('Medical Conditions'),
            _checkboxTile(
              'Diabetes (Type 2)',
              _hasDiabetes,
              (val) => setState(() => _hasDiabetes = val!),
            ),
            _checkboxTile(
              'COPD',
              _hasCOPD,
              (val) => setState(() => _hasCOPD = val!),
            ),
            _checkboxTile(
              'Obesity',
              _hasObesity,
              (val) => setState(() => _hasObesity = val!),
            ),
            _checkboxTile(
              'Post-sternotomy (open heart surgery)',
              _isPostSternotomy,
              (val) => setState(() => _isPostSternotomy = val!),
            ),
            _checkboxTile(
              'Heart failure',
              _hasHeartFailure,
              (val) => setState(() => _hasHeartFailure = val!),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Physical Limitations'),
            _checkboxTile(
              'Lower limb injury or joint problems (knee, hip, ankle)',
              _hasLowerLimbIssue,
              (val) => setState(() => _hasLowerLimbIssue = val!),
            ),
            _checkboxTile(
              'Upper limb injury or shoulder problems',
              _hasUpperLimbIssue,
              (val) => setState(() => _hasUpperLimbIssue = val!),
            ),
            _checkboxTile(
              'Back problems or spinal limitations',
              _hasBackProblem,
              (val) => setState(() => _hasBackProblem = val!),
            ),
            _checkboxTile(
              'Balance issues or increased fall risk',
              _hasBalanceIssue,
              (val) => setState(() => _hasBalanceIssue = val!),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Preferred Activities'),
            _checkboxTile(
              'Walking',
              _likesWalking,
              (val) => setState(() => _likesWalking = val!),
            ),
            _checkboxTile(
              'Cycling',
              _likesCycling,
              (val) => setState(() => _likesCycling = val!),
            ),
            _checkboxTile(
              'Swimming / Water exercise',
              _likesSwimming,
              (val) => setState(() => _likesSwimming = val!),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E5496),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Generate My Plan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E5496),
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2E5496)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (val) =>
          val == null || val.isEmpty ? 'Please fill in this field' : null,
    );
  }

  Widget _phaseSelector() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [1, 2, 3, 4].map((phase) {
          final labels = {
            1: 'Phase 1 — In-hospital',
            2: 'Phase 2 — Early outpatient',
            3: 'Phase 3 — Active rehabilitation',
            4: 'Phase 4 — Maintenance',
          };
          return RadioListTile<int>(
            title: Text(labels[phase]!),
            value: phase,
            groupValue: _selectedPhase,
            activeColor: const Color(0xFF2E5496),
            onChanged: (val) => setState(() => _selectedPhase = val!),
          );
        }).toList(),
      ),
    );
  }

  Widget _checkboxTile(String label, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: CheckboxListTile(
          title: Text(label),
          value: value,
          activeColor: const Color(0xFF2E5496),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final userProfile = UserProfile(
        name: _nameController.text,
        age: int.parse(_ageController.text),
        restingHR: int.parse(_restingHRController.text),
        phase: _selectedPhase,
        hasDiabetes: _hasDiabetes,
        hasCOPD: _hasCOPD,
        hasObesity: _hasObesity,
        isPostSternotomy: _isPostSternotomy,
        hasHeartFailure: _hasHeartFailure,
        hasLowerLimbIssue: _hasLowerLimbIssue,
        hasUpperLimbIssue: _hasUpperLimbIssue,
        hasBackProblem: _hasBackProblem,
        hasBalanceIssue: _hasBalanceIssue,
        likesWalking: _likesWalking,
        likesCycling: _likesCycling,
        likesSwimming: _likesSwimming,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WeeklyScheduleScreen(profile: userProfile),
        ),
      );
    }
  }
}

// ── WEEKLY SCHEDULE SCREEN ────────────────────────────────────

class WeeklyScheduleScreen extends StatefulWidget {
  final UserProfile profile;
  const WeeklyScheduleScreen({super.key, required this.profile});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  final List<SessionLog> _logs = [];

  void _addLog(SessionLog log) {
    setState(() => _logs.add(log));
  }

  IconData _sessionIcon(String focus) {
    if (focus.contains('Resistance')) return Icons.fitness_center;
    if (focus.contains('intervals')) return Icons.speed;
    if (focus.contains('recovery')) return Icons.self_improvement;
    if (focus.contains('Breathing') || focus.contains('Mobility'))
      return Icons.air;
    if (focus.contains('Aerobic + ')) return Icons.swap_horiz;
    return Icons.directions_walk;
  }

  @override
  Widget build(BuildContext context) {
    final planner = ExercisePlanner(widget.profile);
    final week = planner.generateWeek();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E5496),
        title: Text(
          '${widget.profile.name}\'s Weekly Plan',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(widget.profile),
          const SizedBox(height: 16),
          ...week.map((day) => _dayCard(context, day, widget.profile)),
          if (_logs.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sessionLogSection(),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(UserProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E5496),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phase ${profile.phase} — ${profile.sessionsPerWeek == 7 ? 'daily short bouts' : '${profile.sessionsPerWeek} sessions this week'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Target RPE: ${profile.rpeRange} out of 10',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            'Target HR zone: ${profile.targetHRLow}–${profile.targetHRHigh} bpm',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            'Session length: ~${profile.sessionDuration} min',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(BuildContext context, DayPlan day, UserProfile profile) {
    final log = _logs.where((l) => l.dayName == day.dayName).lastOrNull;
    final isCompleted = log != null;

    return GestureDetector(
      onTap: day.isRest
          ? null
          : () async {
              final result = await Navigator.push<SessionLog>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SessionDetailScreen(day: day, profile: profile),
                ),
              );
              if (result != null) _addLog(result);
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted
                ? Colors.teal.shade200
                : day.isRest
                ? Colors.grey.shade200
                : const Color(0xFF2E5496).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.teal.shade100
                    : day.isRest
                    ? Colors.grey.shade100
                    : const Color(0xFF2E5496).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCompleted
                    ? Icons.check_circle
                    : day.isRest
                    ? Icons.hotel
                    : _sessionIcon(day.sessionFocus),
                color: isCompleted
                    ? Colors.teal
                    : day.isRest
                    ? Colors.grey.shade400
                    : const Color(0xFF2E5496),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.dayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: day.isRest
                          ? Colors.grey.shade500
                          : const Color(0xFF1a1a2e),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isCompleted
                        ? 'Completed · RPE ${log.rpe}/10${log.avgHR != null ? ' · Avg HR ${log.avgHR} bpm' : ''}'
                        : day.isRest
                        ? 'Rest day — recovery is part of the programme'
                        : day.sessionFocus,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCompleted
                          ? Colors.teal.shade700
                          : day.isRest
                          ? Colors.grey.shade400
                          : const Color(0xFF2E5496),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!day.isRest && !isCompleted)
                    Text(
                      '${day.allExercises.length} exercises · ~${profile.sessionDuration} min',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            if (!day.isRest && !isCompleted)
              const Icon(Icons.chevron_right, color: Color(0xFF2E5496)),
          ],
        ),
      ),
    );
  }

  Widget _sessionLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Session Log',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E5496),
            ),
          ),
        ),
        ..._logs.map(
          (log) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.teal, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.dayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${log.completedAt.day}/${log.completedAt.month}/${log.completedAt.year} · RPE ${log.rpe}/10'
                        '${log.avgHR != null ? ' · Avg HR ${log.avgHR} bpm' : ''}'
                        '${log.sessionDuration.inMinutes > 0 ? ' · ${log.sessionDuration.inMinutes} min' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (log.note.isNotEmpty)
                        Text(
                          log.note,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── SESSION DETAIL SCREEN (preview before starting) ───────────

class SessionDetailScreen extends StatelessWidget {
  final DayPlan day;
  final UserProfile profile;
  const SessionDetailScreen({
    super.key,
    required this.day,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E5496),
        title: Text(
          day.dayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Focus banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E5496).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Today\'s focus: ${day.sessionFocus}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E5496),
              ),
            ),
          ),
          // Safety warnings
          if (profile.hasDiabetes)
            _warningBanner(
              '⚠️ Diabetes reminder: check blood glucose before starting. Carry fast-acting carbs.',
            ),
          if (profile.isPostSternotomy && profile.phase < 3)
            _warningBanner(
              '⚠️ Post-sternotomy: avoid all upper body loading until cleared by your surgeon.',
            ),
          if (profile.hasHeartFailure)
            _warningBanner(
              '⚠️ Heart failure: stop if breathless at rest. RPE must not exceed 5 today.',
            ),
          if (profile.hasLowerLimbIssue)
            _warningBanner(
              '⚠️ Lower limb limitation: exercises have been adapted. Never push through pain.',
            ),
          if (profile.hasBalanceIssue)
            _warningBanner(
              '⚠️ Balance reminder: always have support nearby. Never exercise near edges or steps alone.',
            ),
          // Exercise preview
          _sectionHeader('Warm-up', Icons.wb_sunny_outlined, Colors.orange),
          ...day.warmUp.map((e) => _exerciseCard(e)),
          const SizedBox(height: 8),
          _sectionHeader(
            'Main Session',
            Icons.fitness_center,
            const Color(0xFF2E5496),
          ),
          ...day.mainSession.map((e) => _exerciseCard(e)),
          const SizedBox(height: 8),
          _sectionHeader('Cool-down', Icons.self_improvement, Colors.teal),
          ...day.coolDown.map((e) => _exerciseCard(e)),
          const SizedBox(height: 32),
          // START SESSION button
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<SessionLog>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ActiveSessionScreen(day: day, profile: profile),
                ),
              );
              if (result != null && context.mounted) {
                Navigator.pop(context, result);
              }
            },
            icon: const Icon(Icons.play_arrow, color: Colors.white),
            label: const Text(
              'Start Session',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5496),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseCard(Exercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1a1a2e),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E5496).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  exercise.duration,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2E5496),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            exercise.variation,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.teal),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  exercise.keyCue,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.teal,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── ACTIVE SESSION SCREEN ─────────────────────────────────────

class ActiveSessionScreen extends StatefulWidget {
  final DayPlan day;
  final UserProfile profile;

  const ActiveSessionScreen({
    super.key,
    required this.day,
    required this.profile,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  // ── Timer state ──
  late final Stopwatch _stopwatch;
  late final Timer _uiTimer;

  // ── Exercise stepper state ──
  int _sectionIndex = 0;
  int _exerciseIndex = 0;

  // ── HR state ──
  late final HeartRateService _hrService;
  StreamSubscription<HRReading>? _hrSub;
  int? _currentHR;
  final List<int> _hrReadings = [];
  int _timeInZoneSeconds = 0;
  Timer? _zoneTimer;

  // ── Safety alert state ──
  bool _showHighHRAlert = false;
  bool _showRPEPrompt = false;
  int _lastRPEPromptMinute = -1;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _hrService = HeartRateService(widget.profile);

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
      _checkRPEPrompt();
    });

    _hrSub = _hrService.heartRateStream().listen((reading) {
      if (!mounted) return;
      setState(() {
        _currentHR = reading.bpm;
        _hrReadings.add(reading.bpm);
      });
      _evaluateSafety(reading.bpm);
    });

    _zoneTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentHR != null) {
        final zone = _hrService.getZone(_currentHR!);
        if (zone.label == 'In zone') {
          _timeInZoneSeconds++;
        }
      }
    });
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _uiTimer.cancel();
    _hrSub?.cancel();
    _zoneTimer?.cancel();
    super.dispose();
  }

  List<List<Exercise>> get _sections => [
    widget.day.warmUp,
    widget.day.mainSession,
    widget.day.coolDown,
  ];

  List<String> get _sectionNames => ['Warm-up', 'Main session', 'Cool-down'];

  Exercise get _currentExercise => _sections[_sectionIndex][_exerciseIndex];

  int get _totalExercises => _sections.fold(0, (sum, s) => sum + s.length);

  int get _completedExercises {
    int count = 0;
    for (int s = 0; s < _sectionIndex; s++) {
      count += _sections[s].length;
    }
    count += _exerciseIndex;
    return count;
  }

  bool get _isFirstExercise => _sectionIndex == 0 && _exerciseIndex == 0;

  bool get _isLastExercise =>
      _sectionIndex == _sections.length - 1 &&
      _exerciseIndex == _sections[_sectionIndex].length - 1;

  void _nextExercise() {
    setState(() {
      if (_exerciseIndex < _sections[_sectionIndex].length - 1) {
        _exerciseIndex++;
      } else if (_sectionIndex < _sections.length - 1) {
        _sectionIndex++;
        _exerciseIndex = 0;
      }
    });
  }

  void _prevExercise() {
    setState(() {
      if (_exerciseIndex > 0) {
        _exerciseIndex--;
      } else if (_sectionIndex > 0) {
        _sectionIndex--;
        _exerciseIndex = _sections[_sectionIndex].length - 1;
      }
    });
  }

  void _evaluateSafety(int bpm) {
    final zone = _hrService.getZone(bpm);
    final isHighAlert =
        zone.label == 'Too high — slow down' ||
        (widget.profile.hasHeartFailure && bpm > widget.profile.targetHRHigh);

    if (isHighAlert && !_showHighHRAlert) {
      HapticFeedback.heavyImpact();
      setState(() => _showHighHRAlert = true);
    } else if (!isHighAlert && _showHighHRAlert) {
      setState(() => _showHighHRAlert = false);
    }
  }

  void _checkRPEPrompt() {
    final minute = _stopwatch.elapsed.inMinutes;
    if (minute > 0 && minute % 10 == 0 && minute != _lastRPEPromptMinute) {
      _lastRPEPromptMinute = minute;
      setState(() => _showRPEPrompt = true);
    }
  }

  int? get _avgHR {
    if (_hrReadings.isEmpty) return null;
    return (_hrReadings.reduce((a, b) => a + b) / _hrReadings.length).round();
  }

  int? get _peakHR {
    if (_hrReadings.isEmpty) return null;
    return _hrReadings.reduce(max);
  }

  void _finishSession() {
    _stopwatch.stop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SessionSummarySheet(
        day: widget.day,
        profile: widget.profile,
        duration: _stopwatch.elapsed,
        avgHR: _avgHR,
        peakHR: _peakHR,
        timeInZoneSeconds: _timeInZoneSeconds,
        hrReadings: List.unmodifiable(_hrReadings),
        onComplete: (log) {
          Navigator.pop(context);
          Navigator.pop(context, log);
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _currentExercise;
    final zone = _currentHR != null ? _hrService.getZone(_currentHR!) : null;

    final sectionColors = [Colors.orange, const Color(0xFF2E5496), Colors.teal];
    final sectionIcons = [
      Icons.wb_sunny_outlined,
      Icons.fitness_center,
      Icons.self_improvement,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E5496),
        title: Text(
          widget.day.dayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => _confirmExit(context),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _formatDuration(_stopwatch.elapsed),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHRBanner(zone),
          if (_showHighHRAlert)
            _buildSafetyAlert(
              'Heart rate too high — slow down or stop and rest.',
              Colors.red,
            ),
          if (widget.profile.hasHeartFailure && !_showHighHRAlert)
            _buildSafetyAlert(
              'Heart failure: stop if breathless at rest. Max RPE 5.',
              Colors.orange,
            ),
          if (_showRPEPrompt) _buildRPECheckIn(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProgressBar(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      sectionIcons[_sectionIndex],
                      color: sectionColors[_sectionIndex],
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _sectionNames[_sectionIndex],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sectionColors[_sectionIndex],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_exerciseIndex + 1} of ${_sections[_sectionIndex].length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCurrentExerciseCard(
                  exercise,
                  sectionColors[_sectionIndex],
                ),
                const SizedBox(height: 16),
                _buildNavigation(),
                const SizedBox(height: 16),
                if (!_isLastExercise) _buildUpcomingList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHRBanner(HRZone? zone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: zone?.color.withOpacity(0.12) ?? Colors.grey.shade100,
      child: Row(
        children: [
          Icon(
            zone?.icon ?? Icons.favorite_border,
            color: zone?.color ?? Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          if (_currentHR != null) ...[
            Text(
              '$_currentHR bpm',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: zone?.color ?? Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              zone?.label ?? '',
              style: TextStyle(
                fontSize: 13,
                color: zone?.color ?? Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else
            Text(
              'Waiting for heart rate…',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          const Spacer(),
          Text(
            'Zone: ${widget.profile.targetHRLow}–${widget.profile.targetHRHigh}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyAlert(String message, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withOpacity(0.12),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRPECheckIn() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: Colors.purple.shade400,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '10-min check: how hard does this feel? (RPE ${widget.profile.rpeRange} target)',
              style: TextStyle(fontSize: 12, color: Colors.purple.shade700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _showRPEPrompt = false),
            child: Text('OK', style: TextStyle(color: Colors.purple.shade600)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _totalExercises == 0
        ? 0.0
        : _completedExercises / _totalExercises;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_completedExercises of $_totalExercises exercises',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF2E5496),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E5496)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentExerciseCard(Exercise exercise, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              exercise.category,
              style: TextStyle(
                fontSize: 11,
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            exercise.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a1a2e),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                exercise.duration,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            exercise.variation,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Colors.teal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exercise.keyCue,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.teal,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isFirstExercise ? null : _prevExercise,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Prev'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: _isFirstExercise
                    ? Colors.grey.shade300
                    : const Color(0xFF2E5496),
              ),
              foregroundColor: _isFirstExercise
                  ? Colors.grey.shade400
                  : const Color(0xFF2E5496),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _isLastExercise
              ? ElevatedButton.icon(
                  onPressed: _finishSession,
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Finish Session',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _nextExercise,
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E5496),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUpcomingList() {
    final upcoming = <({String section, Exercise exercise})>[];
    for (int s = _sectionIndex; s < _sections.length; s++) {
      final startIdx = s == _sectionIndex ? _exerciseIndex + 1 : 0;
      for (int e = startIdx; e < _sections[s].length; e++) {
        upcoming.add((section: _sectionNames[s], exercise: _sections[s][e]));
        if (upcoming.length >= 3) break;
      }
      if (upcoming.length >= 3) break;
    }

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Up next',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        ...upcoming.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.exercise.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1a1a2e),
                        ),
                      ),
                      Text(
                        '${item.section} · ${item.exercise.duration}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End session?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to stop?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text(
              'End session',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SESSION SUMMARY SHEET ─────────────────────────────────────

class SessionSummarySheet extends StatefulWidget {
  final DayPlan day;
  final UserProfile profile;
  final Duration duration;
  final int? avgHR;
  final int? peakHR;
  final int timeInZoneSeconds;
  final List<int> hrReadings;
  final Function(SessionLog) onComplete;

  const SessionSummarySheet({
    super.key,
    required this.day,
    required this.profile,
    required this.duration,
    required this.avgHR,
    required this.peakHR,
    required this.timeInZoneSeconds,
    required this.hrReadings,
    required this.onComplete,
  });

  @override
  State<SessionSummarySheet> createState() => _SessionSummarySheetState();
}

class _SessionSummarySheetState extends State<SessionSummarySheet> {
  double _rpe = 5;
  final _noteController = TextEditingController();

  String _rpeLabel(double rpe) {
    if (rpe <= 1) return 'Nothing at all';
    if (rpe <= 2) return 'Very light';
    if (rpe <= 3) return 'Light';
    if (rpe <= 4) return 'Somewhat light';
    if (rpe <= 5) return 'Moderate';
    if (rpe <= 6) return 'Somewhat hard';
    if (rpe <= 7) return 'Hard';
    if (rpe <= 8) return 'Very hard';
    if (rpe <= 9) return 'Very very hard';
    return 'Maximum effort';
  }

  Color _rpeColor(double rpe) {
    if (rpe <= 3) return Colors.green;
    if (rpe <= 5) return Colors.teal;
    if (rpe <= 7) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatZoneTime() {
    final m = widget.timeInZoneSeconds ~/ 60;
    final s = widget.timeInZoneSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  double get _zonePercent {
    if (widget.duration.inSeconds == 0) return 0;
    return (widget.timeInZoneSeconds / widget.duration.inSeconds).clamp(
      0.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Session complete',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1a1a2e),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.day.sessionFocus,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _statCard(
                  icon: Icons.timer,
                  color: const Color(0xFF2E5496),
                  label: 'Duration',
                  value: _formatDuration(widget.duration),
                ),
                const SizedBox(width: 12),
                _statCard(
                  icon: Icons.favorite,
                  color: Colors.red.shade400,
                  label: 'Avg HR',
                  value: widget.avgHR != null ? '${widget.avgHR} bpm' : '—',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard(
                  icon: Icons.trending_up,
                  color: Colors.orange,
                  label: 'Peak HR',
                  value: widget.peakHR != null ? '${widget.peakHR} bpm' : '—',
                ),
                const SizedBox(width: 12),
                _statCard(
                  icon: Icons.check_circle,
                  color: Colors.teal,
                  label: 'In zone',
                  value: _formatZoneTime(),
                ),
              ],
            ),
            if (widget.hrReadings.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Time in target zone',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _zonePercent,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_zonePercent * 100).round()}% of session in target HR zone '
                '(${widget.profile.targetHRLow}–${widget.profile.targetHRHigh} bpm)',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'How did that feel?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1a1a2e),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Rate your overall perceived effort for the session.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _rpeColor(_rpe).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _rpeColor(_rpe).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_rpe.round()}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _rpeColor(_rpe),
                        ),
                      ),
                      Text(
                        _rpeLabel(_rpe),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _rpeColor(_rpe),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _rpe,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: _rpeColor(_rpe),
                    onChanged: (val) => setState(() => _rpe = val),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1 — Nothing',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        '10 — Maximum',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _rpeTargetFeedback(),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Add a note (optional)',
                hintText: 'e.g. felt short of breath on the walk…',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onComplete(
                    SessionLog(
                      dayName: widget.day.dayName,
                      completedAt: DateTime.now(),
                      rpe: _rpe.round(),
                      note: _noteController.text,
                      sessionDuration: widget.duration,
                      avgHR: widget.avgHR,
                      timeInZoneSeconds: widget.timeInZoneSeconds,
                      peakHR: widget.peakHR,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Session',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rpeTargetFeedback() {
    final rpe = _rpe.round();
    final parts = widget.profile.rpeRange.split('–');
    final low = int.tryParse(parts.first) ?? 0;
    final high = int.tryParse(parts.last) ?? 10;

    String message;
    Color color;

    if (rpe < low) {
      message =
          'Below target RPE (${widget.profile.rpeRange}) — consider a slightly higher effort next time.';
      color = Colors.blue.shade700;
    } else if (rpe > high && rpe > 7) {
      message =
          'Above target RPE (${widget.profile.rpeRange}) — consider easing intensity next session.';
      color = Colors.orange.shade700;
    } else {
      message =
          'RPE within your target range (${widget.profile.rpeRange}). Well done.';
      color = Colors.teal.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
