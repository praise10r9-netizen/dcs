// lib/routes.dart
import 'package:dcs/screens/debug_team_screen.dart';
import 'package:dcs/screens/field_worker_dashboard.dart';
import 'package:dcs/screens/field_worker_data_validation_screen.dart';
import 'package:dcs/screens/formbuilder_screen.dart';
import 'package:dcs/screens/live_data_screen.dart';
import 'package:dcs/screens/login_screen.dart';
import 'package:dcs/screens/registration_screen.dart';
import 'package:dcs/screens/splash_screen.dart';
import 'package:dcs/screens/supervisor_data_cleaning_screen.dart';
import 'package:dcs/screens/team_builder_screen.dart';
import 'package:dcs/screens/supervisor_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:dcs/screens/admin_dashboard.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (_) => SplashScreen(),
  '/login': (_) => LoginScreen(),
  '/register': (_) => RegistrationScreen(),
  '/supervisor': (_) => SupervisorDashboard(),
  '/formBuilder': (_) => FormBuilderScreen(),
  '/organizeTeam': (_) => TeamBuilderScreen(),
  '/fieldWorker': (_) => FieldWorkerDashboard(),
  '/liveSession': (_) => LiveDataScreen(),
  '/dataCleaning': (_) => SupervisorDataCleaningScreen(),
  '/dataValidation': (_) => FieldWorkerDataValidationScreen(),
  '/debugTeams': (_) => DebugTeamScreen(),
  '/admin': (_) => AdminDashboard(),
};