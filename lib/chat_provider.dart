import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_message.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatProvider with ChangeNotifier {
  final List<Message> _messages = [];
  List<Message> get messages => _messages;
  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  Future<void> sendMessage(String content, BuildContext context) async {
    if (_isGenerating) return;
    
    // 检查 API Key
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key') ?? '';
    
    if (apiKey.isEmpty) {
      // 显示对话框
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要 API Key'),
            content: const Text('请先注册 DeepSeek API 服务并创建应用获取 API Key'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  const url = 'https://ppinfra.com/user/register?invited_by=X4GPRK';
                  if (await canLaunch(url)) {
                    await launch(url);
                  }
                },
                child: const Text('去注册'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showApiKeyDialog(context);
                },
                child: const Text('设置 API Key'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    _isGenerating = true;
    notifyListeners();

    // 添加用户消息
    _messages.add(Message(content: content, isUser: true));
    
    // 添加一个空的 AI 响应消息
    final aiMessage = Message(content: '', isUser: false, isComplete: false);
    _messages.add(aiMessage);
    notifyListeners();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('https://api.ppinfra.com/v3/openai/chat/completions'),
      );

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });

      request.body = jsonEncode({
        'model': 'deepseek/deepseek-v3/community',
        'messages': [
          {
            'role': 'system',
            'content': '你是全宇宙最聪明的 AI 助手，你会以诚实专业的态度帮助用户，用中文回答问题。\n开启深度思考。请用 <think> 和</think> 包裹你的内部推理过程，最终回复要简洁自然。\n',
          },
          {
            'role': 'user',
            'content': content,
          }
        ],
        'max_tokens': 10240,
        'stream': true,
      });

      final client = http.Client();
      try {
        final streamedResponse = await client.send(request);
        String buffer = '';

        await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
          for (var line in chunk.split('\n')) {
            if (line.startsWith('data: ')) {
              var data = line.substring(6);
              if (data == '[DONE]') continue;
              
              try {
                var jsonData = jsonDecode(data);
                if (jsonData['choices'] != null && 
                    jsonData['choices'][0]['delta'] != null &&
                    jsonData['choices'][0]['delta']['content'] != null) {
                  var text = jsonData['choices'][0]['delta']['content'] as String;
                  buffer += text;
                  aiMessage.content = buffer;
                  notifyListeners();
                }
              } catch (e) {
                print('Error parsing JSON: $e');
              }
            }
          }
        }
      } finally {
        client.close();
      }
      
      aiMessage.isComplete = true;
      notifyListeners();
      
    } catch (e) {
      print('Error sending message: $e');
      aiMessage.content = '抱歉，发生了错误：$e';
      aiMessage.isComplete = true;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> _showApiKeyDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final keyController = TextEditingController(text: prefs.getString('api_key') ?? '');

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('配置 API Key'),
          content: TextField(
            controller: keyController,
            decoration: const InputDecoration(hintText: '输入你的 API Key'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await prefs.setString('api_key', keyController.text);
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
    }
  }
} 