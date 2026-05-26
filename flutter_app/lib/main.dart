import 'package:flutter/material.dart';
import 'diary_screen.dart';
import 'zianna_main.dart';
import 'fitness.dart';
import 'cardiocare_tab.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Heart Connect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

// ---------------- BOTTOM NAVIGATION ----------------

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  final List<Widget> pages = [
    const HomePage(),
    const DiaryScreen(),
    const ZiannaMain(),
    const Fitness(),
    CardioCareTab(
      token: "YOUR_TOKEN",
      userId: "USER_ID",
      fullName: "USER_NAME",
      role: "patient",
    ),
];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: const Color.fromARGB(255, 3, 3, 4),
        type: BottomNavigationBarType.fixed,

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: "Diary",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Zianna",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: "Fitness Plan",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'CardioCare',
        ),
        ],
      ),
    );
  }
}

// ---------------- HOME PAGE ----------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,

      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: const Text("Heart Connect"),
        centerTitle: true,
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              const Icon(
                Icons.favorite,
                color: Colors.red,
                size: 120,
              ),

              const SizedBox(height: 30),

              const Text(
                "Welcome to the App!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),

                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FormPage(),
                    ),
                  );
                },

                icon: const Icon(Icons.fitness_center),

                label: const Text("Fill In Form"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- FORM PAGE ----------------

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  String selectedHeight = "170-180 cm";
  String selectedWeight = "60-70 kg";
  String selectedAge = "18-25";
  String selectedExperience = "Beginner";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,

      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: const Text("Fitness Form"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            DropdownButton(
              value: selectedHeight,
              isExpanded: true,

              items: [
                "150-160 cm",
                "160-170 cm",
                "170-180 cm",
                "180-190 cm",
              ].map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e),
                );
              }).toList(),

              onChanged: (v) {
                setState(() {
                  selectedHeight = v!;
                });
              },
            ),

            DropdownButton(
              value: selectedWeight,
              isExpanded: true,

              items: [
                "50-60 kg",
                "60-70 kg",
                "70-80 kg",
              ].map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e),
                );
              }).toList(),

              onChanged: (v) {
                setState(() {
                  selectedWeight = v!;
                });
              },
            ),

            DropdownButton(
              value: selectedAge,
              isExpanded: true,

              items: [
                "18-25",
                "26-35",
                "36-45",
              ].map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e),
                );
              }).toList(),

              onChanged: (v) {
                setState(() {
                  selectedAge = v!;
                });
              },
            ),

            DropdownButton(
              value: selectedExperience,
              isExpanded: true,

              items: [
                "Beginner",
                "Intermediate",
                "Advanced",
              ].map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e),
                );
              }).toList(),

              onChanged: (v) {
                setState(() {
                  selectedExperience = v!;
                });
              },
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              child: const Text("Get Exercise Routine"),

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultPage(
                      experience: selectedExperience,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- RESULT PAGE ----------------

class ResultPage extends StatelessWidget {
  final String experience;

  const ResultPage({
    super.key,
    required this.experience,
  });

  String getRoutine() {
    if (experience == "Beginner") {
      return "15 min Walking\nYoga";
    } else if (experience == "Intermediate") {
      return "30 min Jogging\nLight Weight Training";
    } else {
      return "Moderate Weight Training\n6 Days per week";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,

      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: const Text("Fitness Plan"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            const Text(
              "Your Daily Routine",
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),

                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                  ),
                ],
              ),

              child: Text(
                getRoutine(),
                textAlign: TextAlign.center,

                style: const TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}