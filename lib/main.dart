import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'transfer_data.dart';
import 'transfer_screen.dart';
import 'transfer_entry.dart' show TransferEntryScreen;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  final preferences = await SharedPreferences.getInstance();
  runApp(TransferEntryApp(preferences: preferences));
}

class TransferEntryApp extends StatelessWidget {
  const TransferEntryApp({super.key, this.preferences});
  final SharedPreferences? preferences;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'РџРµСЂРµРІРѕРґС‹',
    theme: ThemeData(
      fontFamily: 'RobotoEntry',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2100E8)),
    ),
    home: WelcomeSplash(preferences: preferences),
  );
}

class WelcomeSplash extends StatefulWidget {
  const WelcomeSplash({super.key, this.preferences});
  final SharedPreferences? preferences;

  @override
  State<WelcomeSplash> createState() => _WelcomeSplashState();
}

class _WelcomeSplashState extends State<WelcomeSplash> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => TransferEntryScreen(preferences: widget.preferences),
      ));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Text(
        '\u{41F}\u{440}\u{438}\u{432}\u{435}\u{442}, \u{434}\u{435}\u{442}\u{43A}\u{430} \u{1F49C}',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, this.preferences});
  final SharedPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'РџРµСЂРµРІРѕРґС‹',
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2100E8)),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF252525)),
        ),
      ),
      home: TransferScreen(
        initialData: TransferData(
          minorUnits: preferences?.getInt('demo_amount') ?? 10000,
          recipientName:
              preferences?.getString('demo_recipient') ?? 'Р“Р°Р±РёРґРµРЅ Р–.',
          senderName: preferences?.getString('demo_sender') ?? '',
        ),
        initialFavorite: preferences?.getBool('demo_favorite') ?? false,
        onSave: (data, favorite) async {
          await preferences?.setInt('demo_amount', data.minorUnits);
          await preferences?.setString('demo_recipient', data.recipientName);
          await preferences?.setString('demo_sender', data.senderName);
          await preferences?.setBool('demo_favorite', favorite);
        },
      ),
    );
  }
}
