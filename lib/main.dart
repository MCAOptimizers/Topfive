import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase for Web
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyCGl2NIKaQDMG-cu-EuTFWwzWj65-_G-j8",
            authDomain: "topfive-ac256.firebaseapp.com",
            databaseURL: "https://topfive-ac256-default-rtdb.firebaseio.com",
            projectId: "topfive-ac256",
            storageBucket: "topfive-ac256.appspot.com",
            messagingSenderId: "602647191822",
            appId: "1:602647191822:web:c574f1a48386243aebb75f",
            measurementId: "G-1SXNPD8997"),
      );
    }
  } catch (e) {
    // Handle initialization error
    print('Firebase initialization error: $e');
    // You can also handle the error more gracefully by showing a message to the user
  }

  runApp(MaterialApp(
    home: LoginScreen(),
  ));
}


class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  String? _errorMessage;

  void _login() {
    String password = _passwordController.text;

    // Simpelt tjek af adgangskoder
    if (password == 'user123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyHomePage(isAdmin: false)),
      );
    } else if (password == 'admin123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyHomePage(isAdmin: true)),
      );
    } else {
      setState(() {
        _errorMessage = 'Forkert adgangskode';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Adgangskode',
                errorText: _errorMessage,
              ),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Log ind'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final bool isAdmin;

  MyHomePage({required this.isAdmin});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> leaderboardData = [];
  List<String> gameRules = [];
  List<String> prizes = [];
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  late List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _loadData();
    _widgetOptions = <Widget>[
      widget.isAdmin
          ? AdminProfileTab(
              onReset: _resetLeaderboard,
              onLogout: _logout,
              onSaveGameRules: _saveGameRules,
              onSavePrizes: _savePrizes)
          : ProfileTab(onLogout: _logout),
      LeaderboardTab(
          leaderboardData: leaderboardData,
          gameRules: gameRules,
          prizes: prizes),
      DepartmentLeaderboardTab(leaderboardData: leaderboardData),
      if (widget.isAdmin) // Kun vis "Salg/Hot Lead"-fanen for admins
        SalesHotLeadTab(onSubmit: _submitToFirebase),
    ];
  }

  void _resetLeaderboard() async {
    // Nulstil leaderboard i Firebase med standardværdier
    List<Map<String, dynamic>> defaultEntries = [
      {
        'name': 'Default User',
        'department': 'Default',
        'sales': 0,
        'hotLeads': 0,
        'points': 0
      },
    ];

    await _dbRef.child('leaderboard').set(defaultEntries);
    await _loadData(); // Genindlæs data og opdater UI
    setState(() {
      _selectedIndex =
          1; // Skift til Leaderboard-tab for at vise opdateret data
    });
  }

  Future<void> _saveGameRules(List<String> newRules) async {
    await _dbRef.child('gameRules').set(newRules);
    await _loadData(); // Opdater game rules og opdater UI
    setState(() {
      _selectedIndex =
          1; // Skift til Leaderboard-tab for at vise opdateret data
    });
  }

  Future<void> _savePrizes(List<String> newPrizes) async {
    await _dbRef.child('prizes').set(newPrizes);
    await _loadData(); // Opdater prizes og opdater UI
    setState(() {
      _selectedIndex =
          1; // Skift til Leaderboard-tab for at vise opdateret data
    });
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      _loadData(); // Ensure data is loaded when switching to the leaderboard tab
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _submitToFirebase(
      String employeeName, String department, String type, int count) async {
    int points = type == 'Salg' ? 2 : 1;
    bool employeeExists = false;

    DataSnapshot snapshot = await _dbRef.child('leaderboard').get();
    List<Map<String, dynamic>> leaderboardData = snapshot.exists
        ? List<Map<String, dynamic>>.from((snapshot.value as List)
            .map((item) => Map<String, dynamic>.from(item)))
        : [];

    // Fjern standard værdier hvis de findes
    leaderboardData.removeWhere((entry) => entry['name'] == 'Default User');

    for (var entry in leaderboardData) {
      if (entry['name'].toString().toLowerCase() ==
              employeeName.toLowerCase() &&
          entry['department'].toString().toLowerCase() ==
              department.toLowerCase()) {
        employeeExists = true;
        if (type == 'Salg') {
          entry['sales'] = (entry['sales'] as int? ?? 0) +
              count; // Tilføj til eksisterende antal
        } else {
          entry['hotLeads'] = (entry['hotLeads'] as int? ?? 0) +
              count; // Tilføj til eksisterende antal
        }
        entry['points'] = (entry['points'] as int? ?? 0) + (points * count);
        break;
      }
    }

    if (!employeeExists) {
      leaderboardData.add({
        'name': employeeName,
        'department': department,
        'sales': type == 'Salg' ? count : 0,
        'hotLeads': type == 'Hot Lead' ? count : 0,
        'points': points * count,
      });
    }

    leaderboardData
        .sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

    await _dbRef.child('leaderboard').set(leaderboardData);

    // Automatically switch to the Leaderboard tab
    _onItemTapped(1);
  }

  Future<void> _loadData() async {
    _dbRef.child('leaderboard').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          leaderboardData = List<Map<String, dynamic>>.from(
            (event.snapshot.value as List)
                .map((item) => Map<String, dynamic>.from(item)),
          );
          _widgetOptions = <Widget>[
            widget.isAdmin
                ? AdminProfileTab(
                    onReset: _resetLeaderboard,
                    onLogout: _logout,
                    onSaveGameRules: _saveGameRules,
                    onSavePrizes: _savePrizes)
                : ProfileTab(onLogout: _logout),
            LeaderboardTab(
                leaderboardData: leaderboardData,
                gameRules: gameRules,
                prizes: prizes),
            DepartmentLeaderboardTab(leaderboardData: leaderboardData),
            SalesHotLeadTab(onSubmit: _submitToFirebase),
          ];
        });
      }
    });

    // Load game rules and prizes from Firebase
    _dbRef.child('gameRules').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          gameRules = List<String>.from(event.snapshot.value as List);
        });
      }
    });

    _dbRef.child('prizes').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          prizes = List<String>.from(event.snapshot.value as List);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4b6cb7), // Farve #4b6cb7
            Color(0xFF182848), // Farve #182848
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors
            .transparent, // Sørg for at Scaffold baggrunden er transparent
        body: Center(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
        extendBody:
            true, // For at lade baggrunden bag navigation bar være synlig
        bottomNavigationBar: Stack(
          children: [
            Positioned(
              bottom: 20, // Placerer navigation bar 20 pixels over bunden
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30), // Afrundede hjørner
                child: Container(
                  color:
                      Colors.grey[850], // Mørkegrå baggrund på navigation bar
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent, // Fjerner klik-effekten
                      highlightColor:
                          Colors.transparent, // Fjerner highlight-effekten
                    ),
                    child: BottomNavigationBar(
                      backgroundColor:
                          Colors.transparent, // Gør baggrunden transparent
                      items: <BottomNavigationBarItem>[
                        BottomNavigationBarItem(
                          icon: Icon(Icons.person, color: Colors.white),
                          label: 'Min Profil',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.leaderboard, color: Colors.white),
                          label: 'Leaderboard',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.business, color: Colors.white),
                          label: 'Afdelinger',
                        ),
                        if (widget
                            .isAdmin) // Kun vis "Salg/Hot Lead"-ikonet for admins
                          BottomNavigationBarItem(
                            icon: Icon(Icons.attach_money, color: Colors.white),
                            label: 'Salg/Hot Lead',
                          ),
                      ],
                      currentIndex: _selectedIndex,
                      selectedItemColor: Colors.white,
                      unselectedItemColor: Colors.white, // Holder samme farve
                      onTap: _onItemTapped,
                      elevation: 0, // Fjern skyggen
                      type: BottomNavigationBarType
                          .fixed, // Sørg for at labels vises
                      selectedLabelStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold, // Gør teksten fed
                      ),
                      unselectedLabelStyle: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.normal, // Normal vægt for ikke-valgt
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  final Function onLogout;

  ProfileTab({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Velkommen til Topfive',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => onLogout(),
            child: Text('Log ud'),
          ),
        ],
      ),
    );
  }
}

class AdminProfileTab extends StatelessWidget {
  final Function onReset;
  final Function onLogout;
  final Function(List<String>) onSaveGameRules;
  final Function(List<String>) onSavePrizes;

  AdminProfileTab(
      {required this.onReset,
      required this.onLogout,
      required this.onSaveGameRules,
      required this.onSavePrizes});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 50,
              backgroundImage:
                  NetworkImage('https://example.com/admin-profile-picture.jpg'),
            ),
            SizedBox(height: 20),
            Text(
              'Admin Panel',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => onReset(),
              child: Text('Nulstil Leaderboard'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _editGameRules(context);
              },
              child: Text('Rediger Spilleregler'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _editPrizes(context);
              },
              child: Text('Rediger Præmier'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => onLogout(),
              child: Text('Log ud'),
            ),
          ],
        ),
      ),
    );
  }

  void _editGameRules(BuildContext context) {
    TextEditingController _rulesController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rediger Spilleregler'),
          content: TextField(
            controller: _rulesController,
            decoration: InputDecoration(
                hintText: "Indtast nye spilleregler, adskilt af komma"),
            maxLines: 5,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                List<String> newRules = _rulesController.text
                    .split(',')
                    .map((rule) => rule.trim())
                    .toList();
                onSaveGameRules(newRules);
                Navigator.of(context).pop();
              },
              child: Text('Gem'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuller'),
            ),
          ],
        );
      },
    );
  }

  void _editPrizes(BuildContext context) {
    TextEditingController _prizesController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rediger Præmier'),
          content: TextField(
            controller: _prizesController,
            decoration: InputDecoration(
                hintText: "Indtast nye præmier, adskilt af komma"),
            maxLines: 5,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                List<String> newPrizes = _prizesController.text
                    .split(',')
                    .map((prize) => prize.trim())
                    .toList();
                onSavePrizes(newPrizes);
                Navigator.of(context).pop();
              },
              child: Text('Gem'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuller'),
            ),
          ],
        );
      },
    );
  }
}

class LeaderboardTab extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboardData;
  final List<String> gameRules;
  final List<String> prizes;

  LeaderboardTab(
      {required this.leaderboardData,
      required this.gameRules,
      required this.prizes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Center(
            child: Text(
              'Leaderboard',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Spilleregler',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                        SizedBox(height: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: gameRules.asMap().entries.map((entry) {
                            int index = entry.key + 1;
                            String rule = entry.value;
                            return Text(
                              '$index. $rule',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Præmier',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                        SizedBox(height: 10),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                            children: [
                              WidgetSpan(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: Icon(Icons.emoji_events,
                                      color: Colors.amber, size: 16),
                                ),
                              ),
                              TextSpan(
                                  text:
                                      ' - ${prizes.isNotEmpty ? prizes[0] : 'Præmie 1'}\n'),
                              WidgetSpan(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: Icon(Icons.emoji_events,
                                      color: Colors.grey, size: 16),
                                ),
                              ),
                              TextSpan(
                                  text:
                                      ' - ${prizes.length > 1 ? prizes[1] : 'Præmie 2'}\n'),
                              WidgetSpan(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: Icon(Icons.emoji_events,
                                      color: Colors.brown, size: 16),
                                ),
                              ),
                              TextSpan(
                                  text:
                                      ' - ${prizes.length > 2 ? prizes[2] : 'Præmie 3'}'),
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
          SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: leaderboardData.length,
              itemBuilder: (context, index) {
                IconData? trophyIcon;
                Color? trophyColor;

                if (index == 0) {
                  trophyIcon = Icons.looks_one;
                  trophyColor = Colors.amber;
                } else if (index == 1) {
                  trophyIcon = Icons.looks_two;
                  trophyColor = Colors.grey;
                } else if (index == 2) {
                  trophyIcon = Icons.looks_3;
                  trophyColor = Colors.brown;
                }

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.white,
                  child: ListTile(
                    leading: trophyIcon != null
                        ? Icon(trophyIcon, color: trophyColor, size: 30)
                        : null,
                    title: Text(
                      leaderboardData[index]['name'],
                      style: TextStyle(color: Colors.black),
                    ),
                    subtitle: Text(
                      '${leaderboardData[index]['department']}\n'
                      'Salg: ${leaderboardData[index]['sales']} | Hot Leads: ${leaderboardData[index]['hotLeads']}',
                      style: TextStyle(color: Colors.black54),
                    ),
                    trailing: Text(
                      '${leaderboardData[index]['points']} point',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DepartmentLeaderboardTab extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboardData;

  DepartmentLeaderboardTab({required this.leaderboardData});

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, int>> departmentData = {};

    for (var entry in leaderboardData) {
      final department = entry['department'] as String;
      if (!departmentData.containsKey(department)) {
        departmentData[department] = {
          'sales': 0,
          'points': 0,
        };
      }
      // Tilføj kun salg og beregn point kun baseret på salg
      final sales = entry['sales'] as int;
      departmentData[department]!['sales'] =
          (departmentData[department]!['sales'] ?? 0) + sales;
      departmentData[department]!['points'] =
          (departmentData[department]!['points'] ?? 0) +
              (sales * 2); // 2 point per salg
    }

    // Filtrer afdelinger med 0 point
    final sortedDepartments = departmentData.entries
        .map((e) => {
              'department': e.key,
              'sales': e.value['sales'],
              'points': e.value['points']
            })
        .where((dept) =>
            (dept['points'] as int) > 0) // Fjern afdelinger med 0 point
        .toList();

    sortedDepartments
        .sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

    final topDepartments = sortedDepartments.take(5).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Center(
            child: Text(
              'Top 5 bedste afdelinger',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: topDepartments.length,
              itemBuilder: (context, index) {
                IconData? trophyIcon;
                Color? trophyColor;

                if (index == 0) {
                  trophyIcon = Icons.looks_one;
                  trophyColor = Colors.amber;
                } else if (index == 1) {
                  trophyIcon = Icons.looks_two;
                  trophyColor = Colors.grey;
                } else if (index == 2) {
                  trophyIcon = Icons.looks_3;
                  trophyColor = Colors.brown;
                }

                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.white,
                  child: ListTile(
                    leading: trophyIcon != null
                        ? Icon(trophyIcon, color: trophyColor, size: 30)
                        : null,
                    title: Text(
                      topDepartments[index]['department'] as String,
                      style: TextStyle(color: Colors.black),
                    ),
                    subtitle: Text(
                      'Samlet Salg: ${topDepartments[index]['sales']}',
                      style: TextStyle(color: Colors.black54),
                    ),
                    trailing: Text(
                      '${topDepartments[index]['points']} point',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SalesHotLeadTab extends StatefulWidget {
  final Function(String, String, String, int) onSubmit;

  SalesHotLeadTab({required this.onSubmit});

  @override
  _SalesHotLeadTabState createState() => _SalesHotLeadTabState();
}

class _SalesHotLeadTabState extends State<SalesHotLeadTab> {
  final _formKey = GlobalKey<FormState>();
  final _countController = TextEditingController();
  String? _employeeName;
  String? _department;
  String? _selectedType; // Holder den valgte type (Salg eller Hot Lead)

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _selectedType != null) {
      _formKey.currentState!.save();
      int count = int.parse(_countController.text);
      widget.onSubmit(_employeeName!, _department!, _selectedType!, count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize
              .min, // Sikrer at kolonnen kun fylder den nødvendige plads
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              'Tilføj Salg/Hot Lead',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Medarbejdernavn',
                      labelStyle: TextStyle(
                        color: Colors.grey[850],
                      ),
                      fillColor: Colors.transparent,
                      filled: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    style: TextStyle(color: Colors.grey[850]),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Indtast medarbejdernavn';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _employeeName = value;
                    },
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Afdeling',
                      labelStyle: TextStyle(color: Colors.grey[850]),
                      fillColor: Colors.transparent,
                      filled: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    style: TextStyle(color: Colors.grey[850]),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Indtast afdeling';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _department = value;
                    },
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _countController,
                    decoration: InputDecoration(
                      labelText: 'Antal',
                      labelStyle: TextStyle(color: Colors.grey[850]),
                      hintText: 'Indtast antal',
                      hintStyle: TextStyle(color: Colors.grey[850]),
                      fillColor: Colors.transparent,
                      filled: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    style: TextStyle(color: Colors.grey[850]),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Indtast antal';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Indtast et gyldigt tal';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedType = 'Salg';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedType == 'Salg'
                              ? Colors.black
                              : Colors.grey[850],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Salg',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedType = 'Hot Lead';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedType == 'Hot Lead'
                              ? Colors.black
                              : Colors.grey[850],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Hot Lead',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(
                      'Indsend',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
