import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyArd_o7fXru3a37mSsRLwObLdp8dkwy-Ok",
      appId: "1:224327157558:web:881bb6e167f252a1e49597",
      messagingSenderId: "224327157558",
      projectId: "overwatch-mystery-heroes",
    ),
  );

  runApp(const OverwatchMysteryChallengeApp());
}

class OverwatchMysteryChallengeApp extends StatelessWidget {
  const OverwatchMysteryChallengeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mystery Heroes Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
      ),
      home: const ChallengeScreen(),
    );
  }
}

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  // Full Overwatch 2 Roster (As of recent updates)
  // Full 51-Hero Roster (Updated for 2026)
  final List<String> _allHeroes = [
    // Tanks (14)
    'D.Va', 'Domina', 'Doomfist', 'Hazard', 'Junker Queen', 'Mauga', 'Orisa', 
    'Ramattra', 'Reinhardt', 'Roadhog', 'Sigma', 'Winston', 'Wrecking Ball', 'Zarya',
    
    // Damage (23)
    'Anran', 'Ashe', 'Bastion', 'Cassidy', 'Echo', 'Emre', 'Freja', 'Genji', 
    'Hanzo', 'Junkrat', 'Mei', 'Pharah', 'Reaper', 'Sierra', 'Sojourn', 
    'Soldier: 76', 'Sombra', 'Symmetra', 'Torbjörn', 'Tracer', 'Vendetta', 
    'Venture', 'Widowmaker',
    
    // Support (14)
    'Ana', 'Baptiste', 'Brigitte', 'Illari', 'Jetpack Cat', 'Juno', 'Kiriko', 
    'Lifeweaver', 'Lúcio', 'Mercy', 'Mizuki', 'Moira', 'Wuyang', 'Zenyatta'
  ];

  Set<String> _completedHeroes = {};
  DateTime _lastResetTime = DateTime.now();
  DateTime _lastModified = DateTime.now();
  Timer? _timer;
  User? _user;
  StreamSubscription<User?>? _authSubscription;
  bool _cloudStateLoadInProgress = false;

  final Map<String, Offset> _heroAnimationOffsets = {};
  final Set<String> _animatingHeroes = {};
  static const Duration _heroAnimationDuration = Duration(milliseconds: 320);

  @override
  void initState() {
    super.initState();
    _allHeroes.sort(); // Alphabetical sorting for easy locating
    _loadState();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _user = user;
      });

      if (user != null) {
        _loadStateFromFirebase(user.uid);
      }
    });
    
    // Update the UI every minute to keep the timer accurate
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    final completed = prefs.getStringList('completedHeroes');
    final resetTimeStr = prefs.getString('lastResetTime');
    final lastModifiedStr = prefs.getString('lastModified');

    setState(() {
      if (completed != null) {
        _completedHeroes = completed.toSet();
      }
      if (resetTimeStr != null) {
        _lastResetTime = DateTime.parse(resetTimeStr);
      } else {
        // First launch initialization
        _saveResetTime(_lastResetTime);
      }
      _lastModified = lastModifiedStr != null
          ? DateTime.parse(lastModifiedStr)
          : DateTime.now();
    });
  }

  Future<void> _saveCompletedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('completedHeroes', _completedHeroes.toList());
  }

  Future<void> _saveResetTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastResetTime', time.toIso8601String());
  }

  Future<void> _saveLastModified() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastModified', _lastModified.toIso8601String());
  }

  Future<void> _saveLocalState() async {
    await _saveCompletedState();
    await _saveResetTime(_lastResetTime);
    await _saveLastModified();
  }

  void _queueFirebaseSave() {
    if (_user == null) return;
    if (_cloudStateLoadInProgress) {
      return;
    }

    _saveStateToFirebase();
  }

  void _toggleHero(String hero) {
    if (_animatingHeroes.contains(hero)) return;

    final isComplete = _completedHeroes.contains(hero);
    final direction = isComplete ? const Offset(-1.0, 0) : const Offset(1.0, 0);
    _animatingHeroes.add(hero);
    _heroAnimationOffsets[hero] = Offset.zero;

    setState(() {
      _heroAnimationOffsets[hero] = direction;
    });

    Future.delayed(_heroAnimationDuration, () {
      if (!mounted) return;

      setState(() {
        if (isComplete) {
          _completedHeroes.remove(hero);
        } else {
          _completedHeroes.add(hero);
        }
        _heroAnimationOffsets[hero] = -direction;
      });

      _lastModified = DateTime.now();
      _saveLocalState();
      _queueFirebaseSave();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _heroAnimationOffsets[hero] = Offset.zero;
        });
      });

      Future.delayed(_heroAnimationDuration, () {
        if (!mounted) return;
        setState(() {
          _animatingHeroes.remove(hero);
          _heroAnimationOffsets.remove(hero);
        });
      });
    });
  }

  void _resetChallenge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Challenge?'),
        content: const Text('This will move all heroes back to "In Progress" and reset your timer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _completedHeroes.clear();
                _lastResetTime = DateTime.now();
              });
              _lastModified = DateTime.now();
              _saveLocalState();
              _queueFirebaseSave();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  String _getTimeSinceReset() {
    final duration = DateTime.now().difference(_lastResetTime);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    
    if (days > 0) {
      return '${days}d ${hours}h';
    } else {
      return '${hours}h';
    }
  }

  Future<void> _signInWithGoogle() async {
    GoogleAuthProvider authProvider = GoogleAuthProvider();
    
    try {
      final userCredential = await FirebaseAuth.instance.signInWithPopup(authProvider);
      final user = userCredential.user;
      
      if (user != null) {
        // Run the migration first to catch legacy data
        await _migrateLocalToFirebase(user.uid);
        
        // Pull down the clean cloud data (whether it was just migrated or already existed)
        await _loadStateFromFirebase(user.uid);
      }
    } catch (e) {
      print("Sign in failed: $e");
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      _user = null;
    });
  }

  Future<void> _saveStateToFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Don't save if not logged in

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
          'completedHeroes': _completedHeroes.toList(),
          'lastResetTime': _lastResetTime.toIso8601String(),
          'lastModified': _lastModified.toIso8601String(),
        }, SetOptions(merge: true)); // Merge prevents overwriting unrelated fields
  }

  Future<void> _loadStateFromFirebase(String uid) async {
    _cloudStateLoadInProgress = true;
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await docRef.get();
    _cloudStateLoadInProgress = false;

    bool cloudIsNewer = false;

    if (doc.exists) {
      final data = doc.data()!;
      final cloudCompleted = List<String>.from(data['completedHeroes'] ?? []);
      final cloudResetTime = data['lastResetTime'] != null
          ? DateTime.parse(data['lastResetTime'])
          : DateTime.now();
      final cloudModified = data['lastModified'] != null
          ? DateTime.parse(data['lastModified'])
          : DateTime.fromMillisecondsSinceEpoch(0);

      cloudIsNewer = cloudModified.isAfter(_lastModified);
      if (cloudIsNewer) {
        setState(() {
          _completedHeroes = cloudCompleted.toSet();
          _lastResetTime = cloudResetTime;
          _lastModified = cloudModified;
        });
      }
    }

    if (!cloudIsNewer) {
      await _saveStateToFirebase();
    }
  }

  Future<void> _migrateLocalToFirebase(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    
    final localCompleted = prefs.getStringList('completedHeroes');
    final localResetTimeStr = prefs.getString('lastResetTime');
    final localModifiedStr = prefs.getString('lastModified');
    final localModified = localModifiedStr != null
        ? DateTime.parse(localModifiedStr)
        : DateTime.now();

    if (localCompleted == null && localResetTimeStr == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final docSnapshot = await docRef.get();
    final cloudModified = docSnapshot.exists && docSnapshot.data()?['lastModified'] != null
        ? DateTime.parse(docSnapshot.data()!['lastModified'] as String)
        : DateTime.fromMillisecondsSinceEpoch(0);

    if (!docSnapshot.exists || localModified.isAfter(cloudModified)) {
      await docRef.set({
        'completedHeroes': localCompleted ?? [],
        'lastResetTime': localResetTimeStr ?? DateTime.now().toIso8601String(),
        'lastModified': localModified.toIso8601String(),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inProgressHeroes = _allHeroes.where((h) => !_completedHeroes.contains(h)).toList();
    final completedHeroes = _allHeroes.where((h) => _completedHeroes.contains(h)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mystery Heroes Ult Challenge'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(
              child: Text(
                _user?.email ?? 'Guest',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: Icon(_user == null ? Icons.login : Icons.logout),
            tooltip: _user == null ? 'Sign in with Google' : 'Sign out',
            onPressed: _user == null ? _signInWithGoogle : _signOut,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(
              child: Text(
                'Elapsed: ${_getTimeSinceReset()}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Challenge',
            onPressed: _resetChallenge,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: _buildHeroSection(
              title: 'In Progress (${inProgressHeroes.length})',
              heroes: inProgressHeroes,
              isEmptyMessage: 'Challenge Complete!',
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: _buildHeroSection(
              title: 'Complete (${completedHeroes.length})',
              heroes: completedHeroes,
              isEmptyMessage: 'No heroes completed yet.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection({
    required String title,
    required List<String> heroes,
    required String isEmptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: heroes.isEmpty
              ? Center(
                  child: Text(
                    isEmptyMessage,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                )
              : GridView.extent(
                  maxCrossAxisExtent: 120,
                  padding: const EdgeInsets.all(8.0),
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                  children: heroes.map((hero) => _buildHeroTile(hero)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildHeroTile(String hero) {
    final isComplete = _completedHeroes.contains(hero);
    final offset = _heroAnimationOffsets[hero] ?? Offset.zero;
    final isAnimating = _animatingHeroes.contains(hero);

    return AnimatedSlide(
      key: ValueKey(hero),
      offset: offset,
      duration: _heroAnimationDuration,
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: _heroAnimationDuration,
        opacity: isAnimating ? 0.95 : 1.0,
        child: InkWell(
          onTap: () => _toggleHero(hero),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isComplete 
                  ? Theme.of(context).colorScheme.primaryContainer 
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isComplete 
                    ? Theme.of(context).colorScheme.primary 
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    _getHeroAssetPath(hero),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return CircleAvatar(
                        radius: 28,
                        backgroundColor: isComplete 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).colorScheme.secondary,
                        child: Text(
                          hero.substring(0, 1),
                          style: TextStyle(
                            color: isComplete 
                                ? Theme.of(context).colorScheme.onPrimary 
                                : Theme.of(context).colorScheme.onSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hero,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getHeroAssetPath(String hero) {
    String name = hero.toLowerCase();
    
    // Convert accented letters to standard alphanumeric variants
    name = name.replaceAll('ú', 'u').replaceAll('ö', 'o');
    
    // Strip out spaces, dots, colons, and hyphens (e.g., "d.va" -> "dva")
    name = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    return 'assets/$name.webp';
  }
}