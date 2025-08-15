import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qa_imageprocess/UserAccount/login_page.dart';
import 'package:qa_imageprocess/home_page.dart';
import 'package:qa_imageprocess/pages/system_set.dart';
import 'package:qa_imageprocess/pages/work.dart';
import 'package:qa_imageprocess/user_session.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 仅在非 Web 环境（Windows/macOS/Linux）下初始化窗口管理
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      minimumSize: Size(1400, 850),
      center: true,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  await UserSession().loadFromPrefs();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 58, 108, 183)),
      ),
      home: isLogin() ? const HomePage() : const LoginPage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => LoginPage(),
        '/systemSet': (context) => SystemSet(),
        '/work':(context)=>Work(),
      },
    );
  }
    bool isLogin() {
    if (UserSession().token != null) {
      return true;
    } else {
      return false;
    }
  }
}




