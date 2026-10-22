import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Bottom nav: home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navAgenda.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get navAgenda;

  /// No description provided for @navNetworking.
  ///
  /// In en, this message translates to:
  /// **'Networking'**
  String get navNetworking;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Label for the group of sessions held at a physical venue
  ///
  /// In en, this message translates to:
  /// **'General agenda'**
  String get agendaGeneral;

  /// No description provided for @agendaNoGroupSelected.
  ///
  /// In en, this message translates to:
  /// **'Select at least one program'**
  String get agendaNoGroupSelected;

  /// No description provided for @speakers.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get speakers;

  /// No description provided for @sponsors.
  ///
  /// In en, this message translates to:
  /// **'Sponsors'**
  String get sponsors;

  /// No description provided for @exhibitors.
  ///
  /// In en, this message translates to:
  /// **'Exhibitors'**
  String get exhibitors;

  /// No description provided for @attendees.
  ///
  /// In en, this message translates to:
  /// **'Attendees'**
  String get attendees;

  /// No description provided for @otherActivities.
  ///
  /// In en, this message translates to:
  /// **'Other activities'**
  String get otherActivities;

  /// No description provided for @venue.
  ///
  /// In en, this message translates to:
  /// **'Venues'**
  String get venue;

  /// No description provided for @generalInfo.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get generalInfo;

  /// No description provided for @hotels.
  ///
  /// In en, this message translates to:
  /// **'Accommodation'**
  String get hotels;

  /// No description provided for @organizers.
  ///
  /// In en, this message translates to:
  /// **'Organizers'**
  String get organizers;

  /// No description provided for @transport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get transport;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @meetings.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get meetings;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @liveQuestions.
  ///
  /// In en, this message translates to:
  /// **'Live questions'**
  String get liveQuestions;

  /// No description provided for @polls.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get polls;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @meeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meeting;

  /// No description provided for @addToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to calendar'**
  String get addToCalendar;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @enterAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Enter as guest'**
  String get enterAsGuest;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @emptyGeneric.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show'**
  String get emptyGeneric;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get welcome;

  /// Tooltip for the close (X) button of the fullscreen image viewer
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Accessibility label for a tappable avatar that opens the photo full screen
  ///
  /// In en, this message translates to:
  /// **'Zoom photo'**
  String get zoomPhoto;

  /// Profile section title for theme and language settings
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Label for the language selector
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @networkingLoadMoreError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more attendees.'**
  String get networkingLoadMoreError;

  /// No description provided for @networkingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, company or role'**
  String get networkingSearchHint;

  /// No description provided for @networkingNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get networkingNoResults;

  /// No description provided for @networkingFavoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t saved anyone yet.\nTap the heart in the directory.'**
  String get networkingFavoritesEmpty;

  /// No description provided for @networkingMeetingsReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get networkingMeetingsReceived;

  /// No description provided for @networkingMeetingsConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get networkingMeetingsConfirmed;

  /// No description provided for @networkingMeetingsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get networkingMeetingsPending;

  /// No description provided for @networkingRequestsReceived.
  ///
  /// In en, this message translates to:
  /// **'Requests received'**
  String get networkingRequestsReceived;

  /// No description provided for @networkingNoRequestsReceived.
  ///
  /// In en, this message translates to:
  /// **'You have no meeting requests.'**
  String get networkingNoRequestsReceived;

  /// No description provided for @networkingSentByYou.
  ///
  /// In en, this message translates to:
  /// **'Sent by you'**
  String get networkingSentByYou;

  /// No description provided for @networkingNoRequestsSent.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t sent any requests yet. Find someone in the directory.'**
  String get networkingNoRequestsSent;

  /// No description provided for @networkingAttendee.
  ///
  /// In en, this message translates to:
  /// **'Attendee'**
  String get networkingAttendee;

  /// No description provided for @networkingRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get networkingRemoveFavorite;

  /// No description provided for @networkingSaveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Save to favorites'**
  String get networkingSaveFavorite;

  /// No description provided for @networkingFavoriteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update favorite.'**
  String get networkingFavoriteError;

  /// No description provided for @networkingAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get networkingAbout;

  /// No description provided for @networkingSectors.
  ///
  /// In en, this message translates to:
  /// **'Sectors'**
  String get networkingSectors;

  /// No description provided for @networkingInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get networkingInterests;

  /// No description provided for @networkingSeeking.
  ///
  /// In en, this message translates to:
  /// **'Looking for'**
  String get networkingSeeking;

  /// No description provided for @networkingOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get networkingOffers;

  /// No description provided for @networkingRegions.
  ///
  /// In en, this message translates to:
  /// **'Regions'**
  String get networkingRegions;

  /// No description provided for @networkingSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get networkingSendMessage;

  /// No description provided for @networkingRequestMeeting.
  ///
  /// In en, this message translates to:
  /// **'Request meeting'**
  String get networkingRequestMeeting;

  /// No description provided for @networkingMessagingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Messaging isn\'t available for this event.'**
  String get networkingMessagingUnavailable;

  /// No description provided for @networkingProfileIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Your congress profile is incomplete: complete your registration to be able to save sectors and interests.'**
  String get networkingProfileIncomplete;

  /// No description provided for @networkingProfileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save profile.'**
  String get networkingProfileSaveError;

  /// No description provided for @networkingMyProfile.
  ///
  /// In en, this message translates to:
  /// **'My networking profile'**
  String get networkingMyProfile;

  /// No description provided for @networkingProfileHelp.
  ///
  /// In en, this message translates to:
  /// **'This helps other attendees find you in the directory.'**
  String get networkingProfileHelp;

  /// No description provided for @networkingMySector.
  ///
  /// In en, this message translates to:
  /// **'My sector'**
  String get networkingMySector;

  /// No description provided for @networkingMyInterests.
  ///
  /// In en, this message translates to:
  /// **'My interests'**
  String get networkingMyInterests;

  /// No description provided for @networkingImSeeking.
  ///
  /// In en, this message translates to:
  /// **'I\'m looking for'**
  String get networkingImSeeking;

  /// No description provided for @networkingIOffer.
  ///
  /// In en, this message translates to:
  /// **'I offer solutions in'**
  String get networkingIOffer;

  /// No description provided for @networkingRegionsOfInterest.
  ///
  /// In en, this message translates to:
  /// **'Regions of interest'**
  String get networkingRegionsOfInterest;

  /// No description provided for @networkingSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to network with other attendees.'**
  String get networkingSignInPrompt;

  /// No description provided for @networkingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get networkingRetry;

  /// No description provided for @networkingDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get networkingDirectory;

  /// No description provided for @networkingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Networking isn\'t available for this event.'**
  String get networkingUnavailable;

  /// No description provided for @networkingNoAttendeesPublished.
  ///
  /// In en, this message translates to:
  /// **'No attendees published yet.'**
  String get networkingNoAttendeesPublished;

  /// No description provided for @chatMyChats.
  ///
  /// In en, this message translates to:
  /// **'My chats'**
  String get chatMyChats;

  /// No description provided for @chatSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to message other attendees.'**
  String get chatSignInPrompt;

  /// No description provided for @chatSendError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the message.'**
  String get chatSendError;

  /// No description provided for @chatFirstMessage.
  ///
  /// In en, this message translates to:
  /// **'Write the first message'**
  String get chatFirstMessage;

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get chatMessageHint;

  /// No description provided for @meetingCardOtherPerson.
  ///
  /// In en, this message translates to:
  /// **'the other person'**
  String get meetingCardOtherPerson;

  /// No description provided for @meetingCardDeclineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this request?'**
  String get meetingCardDeclineTitle;

  /// No description provided for @meetingCardDeclineBody.
  ///
  /// In en, this message translates to:
  /// **'The person who sent it will be notified by email.'**
  String get meetingCardDeclineBody;

  /// No description provided for @meetingCardTableByOrganizer.
  ///
  /// In en, this message translates to:
  /// **'The organizer will assign the table.'**
  String get meetingCardTableByOrganizer;

  /// No description provided for @meetingCardRespondError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t respond to the meeting.'**
  String get meetingCardRespondError;

  /// No description provided for @meetingCardNotFound.
  ///
  /// In en, this message translates to:
  /// **'This meeting no longer exists.'**
  String get meetingCardNotFound;

  /// No description provided for @meetingCardCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this meeting?'**
  String get meetingCardCancelTitle;

  /// No description provided for @meetingCardBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get meetingCardBack;

  /// No description provided for @meetingCardCancelMeeting.
  ///
  /// In en, this message translates to:
  /// **'Cancel meeting'**
  String get meetingCardCancelMeeting;

  /// No description provided for @meetingCardCancelError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel the meeting.'**
  String get meetingCardCancelError;

  /// No description provided for @meetingCardCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get meetingCardCancelled;

  /// No description provided for @meetingCardTablePending.
  ///
  /// In en, this message translates to:
  /// **'Table to be assigned'**
  String get meetingCardTablePending;

  /// No description provided for @meetingCardEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get meetingCardEdit;

  /// No description provided for @meetingCardNoSchedule.
  ///
  /// In en, this message translates to:
  /// **'No time proposed'**
  String get meetingCardNoSchedule;

  /// No description provided for @newMeetingEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit meeting'**
  String get newMeetingEditTitle;

  /// No description provided for @newMeetingRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Request meeting'**
  String get newMeetingRequestTitle;

  /// No description provided for @newMeetingCannotEdit.
  ///
  /// In en, this message translates to:
  /// **'This meeting can no longer be edited.'**
  String get newMeetingCannotEdit;

  /// No description provided for @newMeetingAttendeeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This attendee is no longer available for meetings.'**
  String get newMeetingAttendeeUnavailable;

  /// No description provided for @newMeetingSendError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the request.'**
  String get newMeetingSendError;

  /// No description provided for @newMeetingSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save changes.'**
  String get newMeetingSaveError;

  /// No description provided for @newMeetingTopicLabel.
  ///
  /// In en, this message translates to:
  /// **'What would you like to talk about?'**
  String get newMeetingTopicLabel;

  /// No description provided for @newMeetingMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Briefly tell them the reason for the meeting'**
  String get newMeetingMessageHint;

  /// No description provided for @newMeetingProposedDay.
  ///
  /// In en, this message translates to:
  /// **'Proposed day'**
  String get newMeetingProposedDay;

  /// No description provided for @newMeetingStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get newMeetingStartTime;

  /// No description provided for @newMeetingChooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose time'**
  String get newMeetingChooseTime;

  /// No description provided for @newMeetingDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get newMeetingDuration;

  /// No description provided for @newMeetingSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get newMeetingSendRequest;

  /// No description provided for @newMeetingSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get newMeetingSaveChanges;

  /// No description provided for @newMeetingAgendaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check the congress agenda: approximate times are shown and the other person may not be free.'**
  String get newMeetingAgendaUnavailable;

  /// No description provided for @newMeetingCheckingMeetings.
  ///
  /// In en, this message translates to:
  /// **'Checking your meetings…'**
  String get newMeetingCheckingMeetings;

  /// No description provided for @newMeetingCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check your meetings; make sure it doesn\'t overlap.'**
  String get newMeetingCheckFailed;

  /// No description provided for @newMeetingNoFreeTime.
  ///
  /// In en, this message translates to:
  /// **'You have no free time left that day. Try another one.'**
  String get newMeetingNoFreeTime;

  /// No description provided for @newMeetingPickStartTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a start time.'**
  String get newMeetingPickStartTime;

  /// No description provided for @newMeetingOtherPerson.
  ///
  /// In en, this message translates to:
  /// **'The other person'**
  String get newMeetingOtherPerson;

  /// No description provided for @newMeetingPendingAtTime.
  ///
  /// In en, this message translates to:
  /// **'You have an unanswered request at that time.'**
  String get newMeetingPendingAtTime;

  /// No description provided for @meetingSlotAlreadyBooked.
  ///
  /// In en, this message translates to:
  /// **'You already have a meeting at that time.'**
  String get meetingSlotAlreadyBooked;

  /// No description provided for @meetingSlotOtherBusy.
  ///
  /// In en, this message translates to:
  /// **'The other person isn\'t free at that time.'**
  String get meetingSlotOtherBusy;

  /// No description provided for @meetingSlotDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get meetingSlotDone;

  /// No description provided for @authWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get authWrongPassword;

  /// No description provided for @authCouldNotVerifyPassword.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t verify your password. Please try again.'**
  String get authCouldNotVerifyPassword;

  /// No description provided for @authEnterFaster.
  ///
  /// In en, this message translates to:
  /// **'Get in faster'**
  String get authEnterFaster;

  /// No description provided for @authNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get authNotNow;

  /// No description provided for @authActivate.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get authActivate;

  /// No description provided for @authEnableQuickAccess.
  ///
  /// In en, this message translates to:
  /// **'Enable quick access'**
  String get authEnableQuickAccess;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authContinue;

  /// No description provided for @authWrongCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authWrongCredentials;

  /// No description provided for @authCouldNotLogin.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Please try again.'**
  String get authCouldNotLogin;

  /// No description provided for @authPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Your password changed. Enter it again and re-enable quick access.'**
  String get authPasswordChanged;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to experience the congress'**
  String get authLoginSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get authEmailLabel;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'you@email.com'**
  String get authEmailHint;

  /// No description provided for @authEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEnterEmail;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get authInvalidEmail;

  /// No description provided for @authEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authEnterPassword;

  /// No description provided for @profileTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get profileTooManyAttempts;

  /// No description provided for @profileSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Sign out, sign back in, and try again.'**
  String get profileSessionExpired;

  /// No description provided for @profileOptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This option isn\'t available yet. Please try again later.'**
  String get profileOptionUnavailable;

  /// No description provided for @profileAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get profileAccountDeleted;

  /// No description provided for @profileDeleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get profileDeleteAccountConfirmTitle;

  /// No description provided for @profileDeleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your data will be erased and you won\'t be able to sign in with this account. This can\'t be undone.'**
  String get profileDeleteAccountConfirmBody;

  /// No description provided for @profileDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileDelete;

  /// No description provided for @profileDeleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get profileDeleteMyAccount;

  /// No description provided for @profileActionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action can\'t be undone'**
  String get profileActionCannotBeUndone;

  /// No description provided for @profileWhatIsDeleted.
  ///
  /// In en, this message translates to:
  /// **'What gets deleted'**
  String get profileWhatIsDeleted;

  /// No description provided for @profileDeletedPersonalData.
  ///
  /// In en, this message translates to:
  /// **'Your personal and contact details.'**
  String get profileDeletedPersonalData;

  /// No description provided for @profileDeletedNetworkingProfile.
  ///
  /// In en, this message translates to:
  /// **'Your networking profile, your favorites, and your meetings.'**
  String get profileDeletedNetworkingProfile;

  /// No description provided for @profileDeletedQuickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick access with Face ID or fingerprint on this phone.'**
  String get profileDeletedQuickAccess;

  /// No description provided for @profileNoLongerLogin.
  ///
  /// In en, this message translates to:
  /// **'After that you won\'t be able to sign in with this account.'**
  String get profileNoLongerLogin;

  /// No description provided for @profileWhatIsKept.
  ///
  /// In en, this message translates to:
  /// **'What is kept'**
  String get profileWhatIsKept;

  /// No description provided for @profileKeptRegistrations.
  ///
  /// In en, this message translates to:
  /// **'Your registrations and payments, for accounting and tax obligations. They are kept without your contact details.'**
  String get profileKeptRegistrations;

  /// No description provided for @profilePassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get profilePassword;

  /// No description provided for @profilePasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Type it to confirm it\'s you.'**
  String get profilePasswordHelper;

  /// No description provided for @profileEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get profileEnterPassword;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @profileCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the profile.'**
  String get profileCouldNotSave;

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditProfile;

  /// No description provided for @profileFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get profileFirstName;

  /// No description provided for @profileLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get profileLastName;

  /// No description provided for @profilePosition.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get profilePosition;

  /// No description provided for @profileCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get profileCompany;

  /// No description provided for @profileMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get profileMobile;

  /// No description provided for @profileCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileCity;

  /// No description provided for @profileBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBio;

  /// No description provided for @profileSectorsEditedInNetworking.
  ///
  /// In en, this message translates to:
  /// **'Your sectors and interests are edited in your networking profile.'**
  String get profileSectorsEditedInNetworking;

  /// No description provided for @profileGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuest;

  /// No description provided for @profileNoFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get profileNoFavoritesYet;

  /// No description provided for @profileMyNetworkingProfile.
  ///
  /// In en, this message translates to:
  /// **'My networking profile'**
  String get profileMyNetworkingProfile;

  /// No description provided for @profileNetworkingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sectors and interests so others can find you'**
  String get profileNetworkingSubtitle;

  /// No description provided for @profileNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get profileNotifications;

  /// No description provided for @profileCongressAlerts.
  ///
  /// In en, this message translates to:
  /// **'Congress alerts'**
  String get profileCongressAlerts;

  /// No description provided for @profileCongressAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Agenda changes and announcements from the organizer'**
  String get profileCongressAlertsSubtitle;

  /// No description provided for @profileRememberSessions.
  ///
  /// In en, this message translates to:
  /// **'Remind me of my sessions'**
  String get profileRememberSessions;

  /// No description provided for @profileRememberSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A reminder before the sessions you saved'**
  String get profileRememberSessionsSubtitle;

  /// No description provided for @profileRemindMeAhead.
  ///
  /// In en, this message translates to:
  /// **'Remind me ahead of time by'**
  String get profileRemindMeAhead;

  /// No description provided for @profileSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get profileSecurity;

  /// No description provided for @profileLoginWithoutPassword.
  ///
  /// In en, this message translates to:
  /// **'Sign in without typing your password'**
  String get profileLoginWithoutPassword;

  /// No description provided for @profileAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAbout;

  /// No description provided for @profileEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get profileEventLabel;

  /// No description provided for @profileOrganizedBy.
  ///
  /// In en, this message translates to:
  /// **'Organized by'**
  String get profileOrganizedBy;

  /// No description provided for @profileVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get profileVersionLabel;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get profilePrivacyPolicy;

  /// No description provided for @profilePrivacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What data we use and how'**
  String get profilePrivacyPolicySubtitle;

  /// No description provided for @profileTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms and conditions'**
  String get profileTerms;

  /// No description provided for @profileTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rules for using the platform'**
  String get profileTermsSubtitle;

  /// No description provided for @profileContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get profileContact;

  /// No description provided for @profileQuickAccessDisabled.
  ///
  /// In en, this message translates to:
  /// **'Quick access disabled.'**
  String get profileQuickAccessDisabled;

  /// No description provided for @transportNoRoutes.
  ///
  /// In en, this message translates to:
  /// **'No transport routes have been published yet.\nCheck back closer to the congress dates.'**
  String get transportNoRoutes;

  /// No description provided for @transportCongressBuses.
  ///
  /// In en, this message translates to:
  /// **'Congress buses'**
  String get transportCongressBuses;

  /// No description provided for @transportIntroText.
  ///
  /// In en, this message translates to:
  /// **'Transfers between the hotels and the congress venue. Tap a route to see its stops and schedules.'**
  String get transportIntroText;

  /// No description provided for @transportCallOrganizers.
  ///
  /// In en, this message translates to:
  /// **'Call the organizers'**
  String get transportCallOrganizers;

  /// No description provided for @transportRouteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This route is no longer available.'**
  String get transportRouteUnavailable;

  /// No description provided for @transportItinerary.
  ///
  /// In en, this message translates to:
  /// **'Itinerary'**
  String get transportItinerary;

  /// No description provided for @transportDepartureTimes.
  ///
  /// In en, this message translates to:
  /// **'Departure times'**
  String get transportDepartureTimes;

  /// No description provided for @transportNoSchedules.
  ///
  /// In en, this message translates to:
  /// **'No schedules have been published for this route yet.'**
  String get transportNoSchedules;

  /// No description provided for @transportNextDepartureLabel.
  ///
  /// In en, this message translates to:
  /// **'Next departure'**
  String get transportNextDepartureLabel;

  /// No description provided for @transportToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get transportToday;

  /// No description provided for @transportArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get transportArrival;

  /// No description provided for @transportNoDeparturesLeft.
  ///
  /// In en, this message translates to:
  /// **'No scheduled departures left. Check the schedules below.'**
  String get transportNoDeparturesLeft;

  /// No description provided for @transportOpenRouteInGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Open the route in Google Maps'**
  String get transportOpenRouteInGoogleMaps;

  /// No description provided for @transportViewRouteOnMap.
  ///
  /// In en, this message translates to:
  /// **'View the route on the map'**
  String get transportViewRouteOnMap;

  /// No description provided for @transportOpeningCalendar.
  ///
  /// In en, this message translates to:
  /// **'Opening your calendar…'**
  String get transportOpeningCalendar;

  /// No description provided for @transportNoStops.
  ///
  /// In en, this message translates to:
  /// **'This route doesn\'t have published stops yet.'**
  String get transportNoStops;

  /// No description provided for @agendaComingSoon.
  ///
  /// In en, this message translates to:
  /// **'The agenda will be published soon'**
  String get agendaComingSoon;

  /// No description provided for @agendaSessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Session not found'**
  String get agendaSessionNotFound;

  /// No description provided for @agendaDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get agendaDescription;

  /// No description provided for @agendaParticipate.
  ///
  /// In en, this message translates to:
  /// **'Take part'**
  String get agendaParticipate;

  /// No description provided for @agendaSendQuestionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send your question to the panel'**
  String get agendaSendQuestionSubtitle;

  /// No description provided for @agendaAnswerPollSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Answer the live poll'**
  String get agendaAnswerPollSubtitle;

  /// No description provided for @agendaCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get agendaCalendar;

  /// No description provided for @agendaShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get agendaShare;

  /// No description provided for @agendaSponsoredBy.
  ///
  /// In en, this message translates to:
  /// **'Sponsored by'**
  String get agendaSponsoredBy;

  /// No description provided for @homeEventCity.
  ///
  /// In en, this message translates to:
  /// **'Guatemala City'**
  String get homeEventCity;

  /// No description provided for @homeFeaturedAgenda.
  ///
  /// In en, this message translates to:
  /// **'Featured agenda'**
  String get homeFeaturedAgenda;

  /// No description provided for @homeFeaturedSpeakers.
  ///
  /// In en, this message translates to:
  /// **'Featured speakers'**
  String get homeFeaturedSpeakers;

  /// No description provided for @homeOrganizedBy.
  ///
  /// In en, this message translates to:
  /// **'Organized by'**
  String get homeOrganizedBy;

  /// No description provided for @liveQuestionSent.
  ///
  /// In en, this message translates to:
  /// **'Your question was sent. It will appear once the organizer approves it.'**
  String get liveQuestionSent;

  /// No description provided for @liveSignInToAsk.
  ///
  /// In en, this message translates to:
  /// **'Log in to send your question.'**
  String get liveSignInToAsk;

  /// No description provided for @liveSendFailed.
  ///
  /// In en, this message translates to:
  /// **'The question couldn\'t be sent. Try again.'**
  String get liveSendFailed;

  /// No description provided for @liveNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'No approved questions yet.\nSend yours to the speaker.'**
  String get liveNoQuestions;

  /// No description provided for @liveAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get liveAnswer;

  /// No description provided for @liveAwaitingAnswer.
  ///
  /// In en, this message translates to:
  /// **'Awaiting answer'**
  String get liveAwaitingAnswer;

  /// No description provided for @liveGuestNote.
  ///
  /// In en, this message translates to:
  /// **'Log in to send your questions to the speaker.'**
  String get liveGuestNote;

  /// No description provided for @liveQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Write your question…'**
  String get liveQuestionHint;

  /// No description provided for @pollNoPolls.
  ///
  /// In en, this message translates to:
  /// **'No polls in this session'**
  String get pollNoPolls;

  /// No description provided for @pollThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for taking part!'**
  String get pollThanks;

  /// No description provided for @pollVoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Your vote couldn\'t be recorded.'**
  String get pollVoteFailed;

  /// No description provided for @attendeeSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Log in to see attendees and network.'**
  String get attendeeSignInPrompt;

  /// No description provided for @attendeeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, company or sector'**
  String get attendeeSearchHint;

  /// No description provided for @attendeeNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get attendeeNoResults;

  /// No description provided for @attendeeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Attendee not found'**
  String get attendeeNotFound;

  /// No description provided for @attendeeBio.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get attendeeBio;

  /// No description provided for @attendeeInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get attendeeInterests;

  /// No description provided for @attendeeServices.
  ///
  /// In en, this message translates to:
  /// **'Services offered'**
  String get attendeeServices;

  /// No description provided for @speakerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search speakers'**
  String get speakerSearchHint;

  /// No description provided for @speakerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get speakerNoResults;

  /// No description provided for @speakerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Speaker not found'**
  String get speakerNotFound;

  /// No description provided for @speakerBio.
  ///
  /// In en, this message translates to:
  /// **'Biography'**
  String get speakerBio;

  /// No description provided for @speakerSessions.
  ///
  /// In en, this message translates to:
  /// **'Their sessions'**
  String get speakerSessions;

  /// No description provided for @speakerNoSessions.
  ///
  /// In en, this message translates to:
  /// **'This speaker has no published sessions yet.'**
  String get speakerNoSessions;

  /// No description provided for @speakerKeynote.
  ///
  /// In en, this message translates to:
  /// **'Keynote speaker'**
  String get speakerKeynote;

  /// No description provided for @exhibitorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Exhibitor not found'**
  String get exhibitorNotFound;

  /// No description provided for @exhibitorSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search exhibitors'**
  String get exhibitorSearchHint;

  /// No description provided for @commonDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// No description provided for @commonNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get commonNoResults;

  /// No description provided for @commonLoadError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while loading data.'**
  String get commonLoadError;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any favorites yet.\nTap the heart to save what interests you.'**
  String get favoritesEmpty;

  /// No description provided for @favoritesSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get favoritesSessions;

  /// No description provided for @otherActivitiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No additional activities'**
  String get otherActivitiesEmpty;

  /// No description provided for @hotelsSoldOut.
  ///
  /// In en, this message translates to:
  /// **'SOLD OUT'**
  String get hotelsSoldOut;

  /// No description provided for @hotelsOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official hotel'**
  String get hotelsOfficial;

  /// No description provided for @hotelsBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get hotelsBook;

  /// No description provided for @venueScreenPrimary.
  ///
  /// In en, this message translates to:
  /// **'Main venue'**
  String get venueScreenPrimary;

  /// No description provided for @venueScreenPlans.
  ///
  /// In en, this message translates to:
  /// **'Venue plans'**
  String get venueScreenPlans;

  /// No description provided for @venueScreenViewMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get venueScreenViewMap;

  /// No description provided for @widgetRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get widgetRemoveFavorite;

  /// No description provided for @widgetAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get widgetAddFavorite;

  /// No description provided for @networkingAttendeeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attendee} other{{count} attendees}}'**
  String networkingAttendeeCount(int count);

  /// No description provided for @chatYouPrefix.
  ///
  /// In en, this message translates to:
  /// **'You: {text}'**
  String chatYouPrefix(String text);

  /// No description provided for @meetingCardReply.
  ///
  /// In en, this message translates to:
  /// **'Reply: {reply}'**
  String meetingCardReply(String reply);

  /// No description provided for @meetingCardCancelConfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll notify {name}. If a table was assigned, it will be freed.'**
  String meetingCardCancelConfirmedBody(String name);

  /// No description provided for @meetingCardCancelPendingBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer be able to accept it.'**
  String meetingCardCancelPendingBody(String name);

  /// No description provided for @newMeetingEndsAndRequest.
  ///
  /// In en, this message translates to:
  /// **'Ends at {time} · they\'ll get the request to accept or decline it.'**
  String newMeetingEndsAndRequest(String time);

  /// No description provided for @newMeetingEndsAndNotify.
  ///
  /// In en, this message translates to:
  /// **'Ends at {time} · we\'ll let them know about the change.'**
  String newMeetingEndsAndNotify(String time);

  /// No description provided for @newMeetingReconfirm.
  ///
  /// In en, this message translates to:
  /// **'{name} will have to confirm it again and the table will be freed.'**
  String newMeetingReconfirm(String name);

  /// No description provided for @meetingSlotPastClosing.
  ///
  /// In en, this message translates to:
  /// **'That runs past {time}.'**
  String meetingSlotPastClosing(String time);

  /// No description provided for @meetingSlotNeedsNextHalfHour.
  ///
  /// In en, this message translates to:
  /// **'With {minutes}′ you also need the next half hour free.'**
  String meetingSlotNeedsNextHalfHour(int minutes);

  /// No description provided for @meetingSlotEndsAt.
  ///
  /// In en, this message translates to:
  /// **'Ends at {time}.'**
  String meetingSlotEndsAt(String time);

  /// No description provided for @meetingSlotEndsTentative.
  ///
  /// In en, this message translates to:
  /// **'Ends at {time} · you have an unanswered request at that time.'**
  String meetingSlotEndsTentative(String time);

  /// No description provided for @authBiometricEnabledNextTime.
  ///
  /// In en, this message translates to:
  /// **'Done: next time, sign in with {method}.'**
  String authBiometricEnabledNextTime(String method);

  /// No description provided for @authQuickAccessEnabledWith.
  ///
  /// In en, this message translates to:
  /// **'Quick access enabled with {method}.'**
  String authQuickAccessEnabledWith(String method);

  /// No description provided for @authBiometricExplainer.
  ///
  /// In en, this message translates to:
  /// **'Use {method} instead of typing your email and password each time. They\'re stored encrypted on this device and never leave it.'**
  String authBiometricExplainer(String method);

  /// No description provided for @authConfirmPasswordFor.
  ///
  /// In en, this message translates to:
  /// **'Confirm the password for {email} to store it encrypted on this device.'**
  String authConfirmPasswordFor(String email);

  /// No description provided for @authLoginWith.
  ///
  /// In en, this message translates to:
  /// **'Sign in with {method}'**
  String authLoginWith(String method);

  /// No description provided for @profileEnabledFor.
  ///
  /// In en, this message translates to:
  /// **'Enabled for {email}'**
  String profileEnabledFor(String email);

  /// No description provided for @profileYouWillDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'You\'re about to delete the account {email}.'**
  String profileYouWillDeleteAccount(String email);

  /// No description provided for @profileSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} saved'**
  String profileSavedCount(int count);

  /// No description provided for @transportStopsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} stops'**
  String transportStopsCount(int count);

  /// No description provided for @transportApproxMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min approx.'**
  String transportApproxMinutes(int minutes);

  /// No description provided for @transportEveryMinutes.
  ///
  /// In en, this message translates to:
  /// **'every {minutes} min'**
  String transportEveryMinutes(int minutes);

  /// No description provided for @transportNextDeparture.
  ///
  /// In en, this message translates to:
  /// **'Next departure {when}'**
  String transportNextDeparture(String when);

  /// No description provided for @transportNextDepartureWithCountdown.
  ///
  /// In en, this message translates to:
  /// **'Next departure {when} · {countdown}'**
  String transportNextDepartureWithCountdown(String when, String countdown);

  /// No description provided for @transportDirectionsTo.
  ///
  /// In en, this message translates to:
  /// **'How to get to {place}'**
  String transportDirectionsTo(String place);

  /// No description provided for @transportTodayDate.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String transportTodayDate(String date);

  /// No description provided for @transportBusDepartureTitle.
  ///
  /// In en, this message translates to:
  /// **'{route} — bus departure'**
  String transportBusDepartureTitle(String route);

  /// No description provided for @transportPlusMinutes.
  ///
  /// In en, this message translates to:
  /// **'+{minutes} min'**
  String transportPlusMinutes(int minutes);

  /// No description provided for @agendaDayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {number}'**
  String agendaDayNumber(int number);

  /// No description provided for @agendaReminderNotice.
  ///
  /// In en, this message translates to:
  /// **'We\'ll remind you {minutes} min before it starts.'**
  String agendaReminderNotice(int minutes);

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}!'**
  String homeGreeting(String name);

  /// No description provided for @homeDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days} days to go'**
  String homeDaysLeft(int days);

  /// No description provided for @exhibitorStand.
  ///
  /// In en, this message translates to:
  /// **'Booth {booth}'**
  String exhibitorStand(String booth);

  /// No description provided for @hotelsPriceFrom.
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String hotelsPriceFrom(String price);

  /// No description provided for @hotelsReservations.
  ///
  /// In en, this message translates to:
  /// **'Reservations: {contact}'**
  String hotelsReservations(String contact);

  /// No description provided for @networkingAttendeeNotFound.
  ///
  /// In en, this message translates to:
  /// **'That attendee is no longer part of networking.'**
  String get networkingAttendeeNotFound;

  /// No description provided for @networkingLoadCardError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the profile.'**
  String get networkingLoadCardError;

  /// No description provided for @meetingCardActionError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the action.'**
  String get meetingCardActionError;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have no conversations yet.\nMessage someone from their profile in the directory.'**
  String get chatEmpty;

  /// No description provided for @profileDeleteGenericError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete your account. Please try again.'**
  String get profileDeleteGenericError;

  /// No description provided for @authBiometricFingerprint.
  ///
  /// In en, this message translates to:
  /// **'your fingerprint'**
  String get authBiometricFingerprint;

  /// No description provided for @authBiometricDeviceLock.
  ///
  /// In en, this message translates to:
  /// **'your device lock'**
  String get authBiometricDeviceLock;

  /// No description provided for @transportDirHotelToVenue.
  ///
  /// In en, this message translates to:
  /// **'From hotel to venue'**
  String get transportDirHotelToVenue;

  /// No description provided for @transportDirVenueToHotel.
  ///
  /// In en, this message translates to:
  /// **'From venue to hotel'**
  String get transportDirVenueToHotel;

  /// No description provided for @transportDirCircular.
  ///
  /// In en, this message translates to:
  /// **'Circular'**
  String get transportDirCircular;

  /// No description provided for @transportLeavingNow.
  ///
  /// In en, this message translates to:
  /// **'leaving now'**
  String get transportLeavingNow;

  /// No description provided for @transportStopHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get transportStopHotel;

  /// No description provided for @transportStopVenue.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get transportStopVenue;

  /// No description provided for @transportStopFree.
  ///
  /// In en, this message translates to:
  /// **'Meeting point'**
  String get transportStopFree;

  /// No description provided for @transportInMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {minutes} min'**
  String transportInMinutes(int minutes);

  /// No description provided for @transportInHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours} h'**
  String transportInHours(int hours);

  /// No description provided for @transportInHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {hours} h {minutes} min'**
  String transportInHoursMinutes(int hours, int minutes);

  /// No description provided for @meetingCancellationYou.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get meetingCancellationYou;

  /// No description provided for @meetingCancelledBy.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by {who}'**
  String meetingCancelledBy(String who);

  /// No description provided for @meetingCancelledByToday.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by {who} today at {time}'**
  String meetingCancelledByToday(String who, String time);

  /// No description provided for @meetingCancelledByOnDate.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by {who} on {date} at {time}'**
  String meetingCancelledByOnDate(String who, String date, String time);

  /// No description provided for @notifPermTitle.
  ///
  /// In en, this message translates to:
  /// **'Don\'t miss a thing'**
  String get notifPermTitle;

  /// No description provided for @notifPermBody.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications to keep up with agenda changes and congress announcements, and so we can remind you before your saved sessions start.'**
  String get notifPermBody;

  /// No description provided for @notifPermEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get notifPermEnable;

  /// No description provided for @notifPermNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notifPermNotNow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
