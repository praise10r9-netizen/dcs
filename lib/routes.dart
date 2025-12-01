

import 'package:dcs/screens/formbuilder_screen.dart';
import 'package:dcs/screens/login_screen.dart';
import 'package:dcs/screens/registration_screen.dart';
import 'package:dcs/screens/splash_screen.dart';
import 'package:dcs/screens/team_builder_screen.dart';
import 'package:dcs/screens/supervisor_dashboard.dart';
import 'package:flutter/material.dart';

final Map<String, WidgetBuilder> appRoutes =
{
  '/':(_)=> SplashScreen(),
  '/login':(_)=>LoginScreen(),
  '/register':(_)=>RegistrationScreen(),
  '/supervisor':(_)=>SupervisorDashboard(),
  '/formBuilder':(_)=>FormBuilderScreen(),
  '/organizeTeam':(_)=>TeamBuilderScreen(),
  
  '/admin':(_)=>Scaffold(body: Center(child: Text('Admin Dashboard'))),
};