import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:http/http.dart' as http;

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final List<String> allQuestions = [
    'What activities did you do today?',
    'What is your biggest win today?',
    'What symptoms are you experiencing today?',
    'Do you have any stress or worries today?',
    'How is your energy level?',
    'How did you sleep last night?',
  ];

  final List<String> friendNamePool = [
    'Julia',
    'Sam',
    'Marta',
    'Luca',
    'Nina',
  ];

  List<String> friendNames = [];
  List<String> selectedQuestions = [];
  Map<String, String> answers = {};
  Set<String> selectedFriends = {};

  int currentIndex = 0;
  int streakDays = 0;
  bool finished = false;

  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadStreak();
    selectRandomQuestions();
    initializeFriends();
  }

  // ✅ API CALL (fixed)
  Future<void> testApi() async {
    final url = Uri.parse("http://192.168.88.253:3000/");

    try {
      final response = await http.get(url);
      print("API RESPONSE: ${response.body}");
    } catch (e) {
      print("API ERROR: $e");
    }
  }

  void initializeFriends() {
    final random = Random();
    friendNames = friendNamePool.toList()..shuffle(random);
    friendNames = friendNames.take(3).toList();
  }

  Future<void> loadStreak() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      streakDays = prefs.getInt('streakDays') ?? 0;
    });
  }

  void selectRandomQuestions() {
    final random = Random();
    selectedQuestions = [];

    while (selectedQuestions.length < 3) {
      String q = allQuestions[random.nextInt(allQuestions.length)];
      if (!selectedQuestions.contains(q)) {
        selectedQuestions.add(q);
      }
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> answerQuestion() async {
    String text = controller.text.trim();

    if (text.isEmpty) {
      showMessage("Please type an answer");
      return;
    }

    answers[selectedQuestions[currentIndex]] = text;

    if (currentIndex < selectedQuestions.length - 1) {
      setState(() {
        currentIndex++;
        controller.clear();
      });
    } else {
      finishDiary();
    }
  }

  Future<void> finishDiary() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    streakDays++;
    await prefs.setInt('streakDays', streakDays);

    String entry = answers.entries
        .map((e) => "${e.key}: ${e.value}")
        .join("\n");

    await prefs.setString(DateTime.now().toString(), entry);

    setState(() {
      finished = true;
    });
  }

  void previousQuestion() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        controller.text =
            answers[selectedQuestions[currentIndex]] ?? '';
      });
    }
  }

  void skipQuestion() {
    if (currentIndex < selectedQuestions.length - 1) {
      setState(() {
        currentIndex++;
        controller.clear();
      });
    } else {
      finishDiary();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (finished) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Diary Complete"),
          backgroundColor: Colors.green,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 100),
              const SizedBox(height: 20),
              const Text(
                "Thank you for sharing!",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                "Current streak: $streakDays days",
                style: const TextStyle(fontSize: 22),
              ),
            ],
          ),
        ),
      );
    }

    String currentQuestion = selectedQuestions[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Heart Diary"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud),
            onPressed: testApi, // ✅ API button in app bar
          )
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Question ${currentIndex + 1} of ${selectedQuestions.length}",
              style: const TextStyle(fontSize: 22),
            ),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                currentQuestion,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Type your answer...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Share with friends:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 10,
              children: friendNames.map((friend) {
                return FilterChip(
                  label: Text(friend),
                  selected: selectedFriends.contains(friend),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedFriends.add(friend);
                      } else {
                        selectedFriends.remove(friend);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const Spacer(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed:
                      currentIndex > 0 ? previousQuestion : null,
                  child: const Text("Previous"),
                ),
                ElevatedButton(
                  onPressed: answerQuestion,
                  child: const Text("Answer"),
                ),
                ElevatedButton(
                  onPressed: skipQuestion,
                  child: const Text("Skip"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}