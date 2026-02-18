import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/game_anagram/anagram_screen.dart';
import '../../features/game_sentence_code/sentence_code_screen.dart';
import '../../features/game_word_clue/word_clue_screen.dart';
import '../../features/game_word_crash/word_crash_screen.dart';
import '../../features/game_wordle/wordle_provider.dart';
import '../../features/game_wordle/wordle_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../managers/game_state_manager.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/wordle',
      builder: (context, state) {
        return ChangeNotifierProvider(
          create: (_) => WordleProvider(context.read<GameStateManager>()),
          child: const WordleScreen(),
        );
      },
    ),
    GoRoute(
      path: '/word-clue',
      builder: (context, state) => const WordClueScreen(),
    ),
    GoRoute(
      path: '/sentence-code',
      builder: (context, state) => const SentenceCodeScreen(),
    ),
    GoRoute(
      path: '/anagram',
      builder: (context, state) => const AnagramScreen(),
    ),
    GoRoute(
      path: '/word-crash',
      builder: (context, state) => const WordCrashScreen(),
    ),
  ],
);
