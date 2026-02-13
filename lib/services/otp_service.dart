import 'package:firebase_auth/firebase_auth.dart';

class OtpService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;

  // Send OTP to phone number
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution handling if needed
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // Verify the OTP entered by user
  // Returns ID token on success, throws Exception on failure
  Future<String> verifyOtp(String smsCode) async {
    if (_verificationId == null) throw Exception('Verification ID is missing');

    try {
      // Create a PhoneAuthCredential with the code
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Sign the user in
      final userCredential = await _auth.signInWithCredential(credential);

      // Get the ID token to send to backend
      final String? idToken = await userCredential.user?.getIdToken();

      if (idToken == null) throw Exception('Failed to retrieve ID token');

      return idToken;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Verification failed');
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
