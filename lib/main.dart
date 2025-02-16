import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'chat_screen.dart';
import 'chat_provider.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // 确保Flutter绑定初始化
  HttpOverrides.global = MyHttpOverrides();
  
  // 在Android上请求存储权限
  if (Platform.isAndroid) {
    await requestStoragePermission();
  }
  
  runApp(const MyApp());
}

Future<void> requestStoragePermission() async {
  // 检查存储权限
  if (await Permission.storage.status.isDenied) {
    await Permission.storage.request();
  }

  // 检查管理文件权限（Android 11及以上）
  if (await Permission.manageExternalStorage.status.isDenied) {
    await Permission.manageExternalStorage.request();
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ChatProvider(),
      child: MaterialApp(
        title: 'AI智能体',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
