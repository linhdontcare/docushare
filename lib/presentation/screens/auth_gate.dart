import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/firebase/firebase_service.dart';
import '../providers/document_provider.dart';
import '../providers/user_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Lắng nghe thay đổi trạng thái đăng nhập để tự động đồng bộ hồ sơ Supabase
    _authSubscription = FirebaseService.instance.authStateChanges.listen((user) {
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      final docProvider = context.read<DocumentProvider>();
      if (user != null) {
        userProvider.onUserAuthenticated(user).then((_) {
          if (mounted && userProvider.isClaimVerified) {
            docProvider.fetchUserDocuments();
            docProvider.fetchSharedDocuments();
          }
        });
      } else {
        userProvider.onUserSignedOut();
      }
    });

    final currentUser = FirebaseService.instance.currentUser;
    if (currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final userProvider = context.read<UserProvider>();
          final docProvider = context.read<DocumentProvider>();
          userProvider.onUserAuthenticated(currentUser).then((_) {
            if (mounted && userProvider.isClaimVerified) {
              docProvider.fetchUserDocuments();
              docProvider.fetchSharedDocuments();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _retryFirebase() async {
    await FirebaseService.instance.initialize();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final firebase = FirebaseService.instance;
    if (!firebase.isAvailable) {
      return LoginScreen(
        initializationError: firebase.initializationError,
        onRetry: _retryFirebase,
      );
    }

    return StreamBuilder<User?>(
      stream: firebase.authStateChanges,
      initialData: firebase.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return user == null ? const LoginScreen() : const HomeScreen();
      },
    );
  }
}

