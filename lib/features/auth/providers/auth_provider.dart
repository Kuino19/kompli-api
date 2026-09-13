import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/document_service.dart';
import '../../../services/compliance_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final authProvider = NotifierProvider<AuthNotifier, void>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<String?> login(String email, String password) async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.signInWithEmailAndPassword(email: email, password: password);
      // Sync local offline data to Firestore after login
      await DocumentService().syncOfflineDocuments();
      await ComplianceService().syncOfflineStatuses();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code; // Return code so UI can show friendly message
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signup(String email, String password) async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await DocumentService().syncOfflineDocuments();
      await ComplianceService().syncOfflineStatuses();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.sendPasswordResetEmail(email: email);
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No account found with that email.';
      }
      return e.message ?? 'Failed to send reset email.';
    } catch (e) {
      return 'An error occurred. Please try again.';
    }
  }

  Future<void> logout() async {
    final auth = ref.read(firebaseAuthProvider);
    await auth.signOut();
  }
}
