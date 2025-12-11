// lib/app_routes.dart
import 'package:flutter/material.dart';

// Core
import 'package:runrank/auth/login_screen.dart';
import 'package:runrank/root_navigation.dart';

// History / records
import 'package:runrank/history_screen.dart';

// Club hub / events
import 'package:runrank/widgets/training_events_calendar.dart';
import 'package:runrank/widgets/admin_create_event_page.dart';

// Menu pages
import 'package:runrank/menu/user_profile_page.dart';
import 'package:runrank/menu/membership_page.dart';
import 'package:runrank/menu/charity_page.dart';
import 'package:runrank/menu/club_history_page.dart';
import 'package:runrank/menu/merchandise_page.dart';
import 'package:runrank/admin/admin_charity_page.dart';

// Notifications
import 'package:runrank/notifications_screen.dart';

// Register
import 'package:runrank/auth/register_club_screen.dart';

class AppRoutes {
  // Route names
  static const login = '/login';
  static const root = '/root';
  static const history = '/history';
  static const clubHub = '/club-hub';
  static const adminCreateEvent = '/admin-create-event';
  static const userProfile = '/user-profile';
  static const membership = '/membership';
  static const charity = '/charity';
  static const clubHistory = '/club-history';
  static const merchandise = '/merchandise';
  static const adminCharity = '/admin-charity';
  static const notifications = '/notifications';
  static const register = '/register';

  // Route table
  static Map<String, WidgetBuilder> routes = {
    login: (_) => const LoginScreen(),
    root: (_) => const RootNavigation(),
    history: (_) => const HistoryScreen(),
    clubHub: (_) => const TrainingEventsCalendar(),
    userProfile: (_) => const UserProfilePage(),
    membership: (_) => const MembershipPage(),
    charity: (_) => const CharityPage(),
    clubHistory: (_) => const ClubHistoryPage(),
    merchandise: (_) => const MerchandisePage(),
    adminCharity: (_) => const AdminCharityEditorPage(),
    notifications: (_) => const NotificationsScreen(),
    register: (_) => const RegisterClubScreen(),
  };
}
