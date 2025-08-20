import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qa_imageprocess/UserAccount/login_page.dart';
import 'package:qa_imageprocess/home_page.dart';
import 'package:qa_imageprocess/pages/inspect.dart';
import 'package:qa_imageprocess/pages/system_set.dart';
import 'package:qa_imageprocess/pages/work.dart';
import 'package:qa_imageprocess/pages/work_arrange.dart';
import 'package:qa_imageprocess/tools/ai_service.dart';
import 'package:qa_imageprocess/user_session.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 仅在非 Web 环境下初始化窗口管理
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      minimumSize: Size(1380, 780),
      center: true,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  await UserSession().loadFromPrefs();
  await AiService.initData();
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 58, 108, 183),
        ),
        fontFamily: 'YeHei',
      ),
      home: isLogin() ? const HomePage() : const LoginPage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => LoginPage(),
        '/systemSet': (context) => SystemSet(),
        '/workDetail': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return WorkDetailScreen(workID: args['workID']);
        },
<<<<<<< HEAD
        '/workArrange': (context) => WorkArrange(),
=======
        '/Inspect': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return Inspect(workID: args['workID']);
        },
        '/workArrange':(context)=>WorkArrange(),
>>>>>>> 625f0a5ed634dd61e7cbd2cc3535241e41f3c85f
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
