import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to Test²'),
            ElevatedButton(
              onPressed: () {
                // TODO: Add sign in logic
              },
              child: const Text('Sign In with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
