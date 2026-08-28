import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/user_provider.dart';
import '../../features/agenda/agenda_screen.dart';
import '../../features/agenda/session_detail_screen.dart';
import '../../features/attendees/attendee_detail_screen.dart';
import '../../features/attendees/attendees_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/exhibitors/exhibitor_detail_screen.dart';
import '../../features/exhibitors/exhibitors_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/live/live_questions_screen.dart';
import '../../features/live/polls_screen.dart';
import '../../features/networking/networking_screen.dart';
import '../../features/networking/new_meeting_screen.dart';
import '../../features/other_activities/other_activities_screen.dart';
import '../../features/profile/profile_edit_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../features/speakers/speaker_detail_screen.dart';
import '../../features/speakers/speakers_screen.dart';
import '../../features/sponsors/sponsor_detail_screen.dart';
import '../../features/sponsors/sponsors_screen.dart';
import '../../features/venue/hotels_screen.dart';
import '../../features/venue/info_screen.dart';
import '../../features/venue/organizers_screen.dart';
import '../../features/venue/venues_screen.dart';
import 'route_paths.dart';

/// Puente entre el estado de auth (Riverpod) y el `refreshListenable` de go_router.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: R.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(isLoggedInProvider);
      final loggingIn = state.matchedLocation == R.login;
      if (!loggedIn) return loggingIn ? null : R.login;
      if (loggingIn) return R.home;
      return null;
    },
    routes: [
      GoRoute(path: R.login, builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: R.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: R.agenda, builder: (_, _) => const AgendaScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: R.networking, builder: (_, _) => const NetworkingScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: R.profile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(path: R.speakers, builder: (_, _) => const SpeakersScreen()),
      GoRoute(
        path: '${R.speakerDetail}/:id',
        builder: (_, state) => SpeakerDetailScreen(speakerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${R.sessionDetail}/:id',
        builder: (_, state) => SessionDetailScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(path: R.sponsors, builder: (_, _) => const SponsorsScreen()),
      GoRoute(
        path: '${R.sponsorDetail}/:id',
        builder: (_, state) => SponsorDetailScreen(sponsorId: state.pathParameters['id']!),
      ),
      GoRoute(path: R.exhibitors, builder: (_, _) => const ExhibitorsScreen()),
      GoRoute(
        path: '${R.exhibitorDetail}/:id',
        builder: (_, state) => ExhibitorDetailScreen(exhibitorId: state.pathParameters['id']!),
      ),
      GoRoute(path: R.otherActivities, builder: (_, _) => const OtherActivitiesScreen()),
      GoRoute(path: R.venues, builder: (_, _) => const VenuesScreen()),
      GoRoute(path: R.info, builder: (_, _) => const InfoScreen()),
      GoRoute(path: R.hotels, builder: (_, _) => const HotelsScreen()),
      GoRoute(path: R.organizers, builder: (_, _) => const OrganizersScreen()),
      GoRoute(path: R.favorites, builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: R.attendees, builder: (_, _) => const AttendeesScreen()),
      GoRoute(
        path: '${R.attendeeDetail}/:id',
        builder: (_, state) => AttendeeDetailScreen(attendeeId: state.pathParameters['id']!),
      ),
      GoRoute(path: R.chats, builder: (_, _) => const ChatListScreen()),
      GoRoute(
        path: '${R.chat}/:id',
        builder: (_, state) => ChatScreen(attendeeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${R.newMeeting}/:id',
        builder: (_, state) => NewMeetingScreen(attendeeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${R.liveQuestions}/:id',
        builder: (_, state) => LiveQuestionsScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${R.polls}/:id',
        builder: (_, state) => PollsScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(path: R.profileEdit, builder: (_, _) => const ProfileEditScreen()),
    ],
  );
});
