/// Rutas de la app (go_router). Centralizadas para navegar con seguridad.
abstract final class R {
  // Auth
  static const login = '/login';

  // Pestañas del shell (bottom navigation)
  static const home = '/home';
  static const agenda = '/agenda';
  static const networking = '/networking';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';

  // Drill-downs (se apilan sobre el shell)
  static const speakers = '/speakers';
  static const speakerDetail = '/speaker'; // /speaker/:id
  static const sponsors = '/sponsors';
  static const sponsorDetail = '/sponsor'; // /sponsor/:id
  static const exhibitors = '/exhibitors';
  static const exhibitorDetail = '/exhibitor'; // /exhibitor/:id
  static const attendees = '/attendees';
  static const attendeeDetail = '/attendee'; // /attendee/:id
  static const sessionDetail = '/session'; // /session/:id
  static const otherActivities = '/other-activities';
  static const venues = '/venues';
  static const info = '/info';
  static const hotels = '/hotels';
  static const organizers = '/organizers';
  static const favorites = '/favorites';

  // Interactivos
  static const meetings = '/meetings';
  static const newMeeting = '/new-meeting'; // /new-meeting/:attendeeId
  static const chats = '/chats';
  static const chat = '/chat'; // /chat/:attendeeId
  static const liveQuestions = '/live-questions'; // /live-questions/:sessionId
  static const polls = '/polls'; // /polls/:sessionId

  // Helpers para construir rutas con parámetros
  static String speaker(String id) => '$speakerDetail/$id';
  static String sponsor(String id) => '$sponsorDetail/$id';
  static String exhibitor(String id) => '$exhibitorDetail/$id';
  static String attendee(String id) => '$attendeeDetail/$id';
  static String session(String id) => '$sessionDetail/$id';
  static String meetingWith(String attendeeId) => '$newMeeting/$attendeeId';
  static String chatWith(String attendeeId) => '$chat/$attendeeId';
  static String liveQuestionsFor(String sessionId) => '$liveQuestions/$sessionId';
  static String pollsFor(String sessionId) => '$polls/$sessionId';
}
