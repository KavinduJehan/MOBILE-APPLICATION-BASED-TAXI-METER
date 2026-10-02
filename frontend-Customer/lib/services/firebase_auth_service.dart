import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Formats phone number into international E.164 format.
  /// Converts Sri Lankan numbers (e.g. 0771234567) to +94771234567.
  static String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.startsWith('0')) {
      return '+94${cleaned.substring(1)}';
    }
    if (cleaned.startsWith('94')) {
      return '+$cleaned';
    }
    return '+94$cleaned';
  }

  /// Sends SMS OTP using Firebase Authentication.
  /// On Firebase Spark (Free) plan:
  /// - 10 real SMS/day free.
  /// - Unlimited test phone numbers (configured in Firebase Console).
  static Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onVerificationFailed,
    required void Function(String idToken) onAutoVerified,
    int? resendToken,
  }) async {
    final formattedPhone = formatPhoneNumber(phoneNumber);

    await _auth.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final userCredential = await _auth.signInWithCredential(credential);
          final idToken = await userCredential.user?.getIdToken();
          if (idToken != null) {
            onAutoVerified(idToken);
          }
        } catch (e) {
          onVerificationFailed(e.toString());
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        String msg = e.message ?? 'Phone verification failed';
        if (e.code == 'invalid-phone-number') {
          msg = 'Invalid phone number format.';
        } else if (e.code == 'too-many-requests') {
          msg = 'Too many requests. Please try again later or use test phone number.';
        } else if (e.code == 'quota-exceeded') {
          msg = 'Daily SMS quota exceeded. Please use Firebase test phone numbers.';
        }
        onVerificationFailed(msg);
      },
      codeSent: (String verificationId, int? newResendToken) {
        onCodeSent(verificationId, newResendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Auto-retrieval timed out (user can still enter code manually)
      },
    );
  }

  /// Verifies user-entered OTP and returns Firebase ID token.
  static Future<String> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Failed to obtain Firebase ID token');
    }
    return idToken;
  }

  /// Signs out from Firebase Auth session.
  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
