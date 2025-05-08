import 'package:flutter/material.dart';
import 'package:yapartner/screens/main_screen.dart';
import 'package:yapartner/services/yandex_api_service.dart';
import 'package:yapartner/theme.dart';
import 'services/token_storage.dart';

void main() {
  runApp(YaAdsPartnerApp());
}

class YaAdsPartnerApp extends StatelessWidget {
  const YaAdsPartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YaAdsPartner',
      theme: yaAdsPartnerTheme,
      home: TokenGate(apiService: YandexApiService()),
    );
  }
}

class TokenGate extends StatefulWidget {
  final YandexApiService? apiService;

  const TokenGate({super.key, this.apiService});

  @override
  _TokenGateState createState() => _TokenGateState();
}

class _TokenGateState extends State<TokenGate> {
  String? _token;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  void _loadToken() async {
    final token = await TokenStorage.getToken();
    if (token != null) {
      setState(() => _token = token);
    }
  }

  void _saveToken() async {
    final token = _controller.text.trim();
    if (token.isNotEmpty) {
      await TokenStorage.saveToken(token);
      setState(() => _token = token);
    }
    // TODO add simple token validation
  }

  @override
  Widget build(BuildContext context) {
    if (_token != null) {
      return MainPage(token: _token!, apiService: widget.apiService);
    }

    return Scaffold(
      appBar: AppBar(title: Text('Enter OAuth Token')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'OAuth Token'),
              obscureText: true,
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _saveToken, child: Text('Continue')),
          ],
        ),
      ),
    );
  }
}
