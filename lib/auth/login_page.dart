import 'package:flutter/material.dart';
import '../core/notifier.dart';
import '../core/supabase.dart';
import '../services/auth_service.dart';
import '../pages/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    if (email.text.isEmpty || pass.text.isEmpty) {
      notify(context, 'Email & password wajib diisi', error: true);
      return;
    }

    setState(() => loading = true);

    try {
      await Supa.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: pass.text.trim(),
      );

      // 🔥 WAJIB LOAD PROFILE
      await AuthService.loadProfile();

      notify(context, 'Login berhasil');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      notify(context, 'Email atau password salah', error: true);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'POS Coffee Shop',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : login,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text('LOGIN'),
            ),
          ],
        ),
      ),
    );
  }
}
