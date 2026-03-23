import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common/providers/auth_provider.dart';
import 'routes/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const KdsApp());
}

class KdsApp extends StatefulWidget {
  const KdsApp({super.key});

  @override
  State<KdsApp> createState() => _KdsAppState();
}

class _KdsAppState extends State<KdsApp> {
  late final AuthProvider _authProvider;
  late final router;

  @override
  void initState() {
    super.initState();
    // Se crean UNA SOLA VEZ — no se recrean en cada rebuild
    _authProvider = AuthProvider()..checkSession();
    router = createRouter(_authProvider);
  }

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _authProvider,
      child: MaterialApp.router(
        title: 'KDS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Inter',
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
          useMaterial3: true,
        ),
        routerConfig: router,
      ),
    );
  }
}