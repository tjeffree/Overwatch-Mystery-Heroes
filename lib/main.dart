import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
  Timer? _timer;

  final Map<String, Offset> _heroAnimationOffsets = {};
  final Set<String> _animatingHeroes = {};
  static const Duration _heroAnimationDuration = Duration(milliseconds: 320);

  @override
  void initState() {
    super.initState();
    _allHeroes.sort(); // Alphabetical sorting for easy locating
    _loadState();
    
    // Update the UI every minute to keep the timer accurate
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    
    final completed = prefs.getStringList('completedHeroes');
    final resetTimeStr = prefs.getString('lastResetTime');

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

      _saveCompletedState();

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
              _saveCompletedState();
              _saveResetTime(_lastResetTime);
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

  @override
  Widget build(BuildContext context) {
    final inProgressHeroes = _allHeroes.where((h) => !_completedHeroes.contains(h)).toList();
    final completedHeroes = _allHeroes.where((h) => _completedHeroes.contains(h)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mystery Heroes Ult Challenge'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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