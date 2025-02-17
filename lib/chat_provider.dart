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

      // 构建消息历史
      List<Map<String, dynamic>> messageHistory = [
        // 添加 system 消息
        {
          'role': 'system',
          'content': '你是一个全宇宙最聪明的AI智能体，你会以诚实专业的态度帮助用户，用中文回答问题。\n开启深度思考。请用"深度思考:"来表达你的内部推理过程，最终回复要简洁自然。\n'
        }
      ];

      // 遍历所有消息构建历史记录
      for (var i = 0; i < _messages.length - 1; i++) {  // -1 是因为最后一条是空的AI消息
        Message msg = _messages[i];
        String content = msg.content;
        
        // 如果是 AI 的回复，将"深度思考:"转换为 <think> 标签
        // if (!msg.isUser) {
          content = content.replaceAll('已开启深度思考:', '<think>');
          content = content.replaceAll('\n思考完成,开始回答问题:', '</think>');
        // }
        
        messageHistory.add({
          'role': msg.isUser ? 'user' : 'assistant',
          'content': content
        });
      }

      request.body = jsonEncode({
        'model': 'deepseek/deepseek-r1/community',
        'messages': messageHistory,
        'max_tokens': 10240,
        'frequency_penalty': 0,
        'presence_penalty': 0,
        'repetition_penalty': 1,
        'temperature': 1,
        'top_k': 50,
        'top_p': 1,
        'stream': true
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
                  
                  // 将 <think> 标签转换为"深度思考:"
                  text = text.replaceAll('<think>', '已开启深度思考:');
                  text = text.replaceAll('</think>', '\n思考完成,开始回答问题:');
                  
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