import 'package:flutter/material.dart';

/// Íconos de la app mapeados a Material Icons.
///
/// Se conservan los nombres `PhosphorIconsRegular` / `PhosphorIconsFill` como
/// fachada para no tocar los call sites: el paquete `phosphor_flutter` extiende
/// `IconData`, que en Flutter 3.44 es una clase `final` (no extensible), por lo
/// que rompía la compilación. Material Icons es 100% compatible.
abstract final class PhosphorIconsRegular {
  static const IconData airplane = Icons.flight;
  static const IconData bed = Icons.bed_outlined;
  static const IconData bell = Icons.notifications_none_rounded;
  static const IconData briefcase = Icons.business_center_outlined;
  static const IconData buildings = Icons.apartment_rounded;
  static const IconData calendarBlank = Icons.calendar_today_rounded;
  static const IconData calendarDots = Icons.calendar_month_outlined;
  static const IconData calendarPlus = Icons.event_available_outlined;
  static const IconData calendarStar = Icons.event_rounded;
  static const IconData caretLeft = Icons.arrow_back_ios_new_rounded;
  static const IconData caretRight = Icons.chevron_right_rounded;
  static const IconData chartBar = Icons.bar_chart_rounded;
  static const IconData chatCircleText = Icons.chat_bubble_outline_rounded;
  static const IconData chatsCircle = Icons.forum_outlined;
  static const IconData check = Icons.check_rounded;
  static const IconData clock = Icons.schedule_rounded;
  static const IconData clockCountdown = Icons.timer_outlined;
  static const IconData compass = Icons.explore_outlined;
  static const IconData confetti = Icons.celebration_rounded;
  static const IconData deviceMobile = Icons.smartphone_rounded;
  static const IconData envelopeSimple = Icons.mail_outline_rounded;
  static const IconData forkKnife = Icons.restaurant_rounded;
  static const IconData globe = Icons.language_rounded;
  static const IconData handshake = Icons.handshake_outlined;
  static const IconData heart = Icons.favorite_border_rounded;
  static const IconData houseSimple = Icons.home_outlined;
  static const IconData identificationCard = Icons.badge_outlined;
  static const IconData info = Icons.info_outline_rounded;
  static const IconData magnifyingGlass = Icons.search_rounded;
  static const IconData mapPin = Icons.location_on_outlined;
  static const IconData mapPinLine = Icons.location_on_rounded;
  static const IconData mapTrifold = Icons.map_outlined;
  static const IconData medal = Icons.workspace_premium_rounded;
  static const IconData paperPlaneRight = Icons.send_rounded;
  static const IconData thumbsUp = Icons.thumb_up_alt_outlined;
  static const IconData microphoneStage = Icons.record_voice_over_rounded;
  static const IconData moon = Icons.dark_mode_outlined;
  static const IconData pencilSimple = Icons.edit_outlined;
  static const IconData phone = Icons.call_outlined;
  static const IconData shareNetwork = Icons.share_outlined;
  static const IconData signOut = Icons.logout_rounded;
  static const IconData storefront = Icons.storefront_outlined;
  static const IconData sun = Icons.light_mode_outlined;
  static const IconData tray = Icons.inbox_outlined;
  static const IconData trophy = Icons.emoji_events_outlined;
  static const IconData user = Icons.person_outline_rounded;
  static const IconData usersThree = Icons.groups_outlined;
  static const IconData warning = Icons.error_outline_rounded;
  static const IconData x = Icons.close_rounded;
}

abstract final class PhosphorIconsFill {
  static const IconData calendarDots = Icons.calendar_month;
  static const IconData facebookLogo = Icons.facebook;
  static const IconData heart = Icons.favorite_rounded;
  static const IconData houseSimple = Icons.home_rounded;
  static const IconData instagramLogo = Icons.camera_alt_rounded;
  static const IconData linkedinLogo = Icons.business_center_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData user = Icons.person_rounded;
  static const IconData usersThree = Icons.groups_rounded;
  static const IconData xLogo = Icons.alternate_email_rounded;
}
