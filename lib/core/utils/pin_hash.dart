import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PinHash {
  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hashPin({
    required String pin,
    required String salt,
  }) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  static String hashPinPbkdf2({
    required String pin,
    required String salt,
    int iterations = 500,
  }) {
    final key = utf8.encode(pin);
    final saltBytes = utf8.encode(salt);
    final hmac = Hmac(sha256, key);
    
    final initialBytes = <int>[];
    initialBytes.addAll(saltBytes);
    initialBytes.addAll([0, 0, 0, 1]);
    var block = hmac.convert(initialBytes).bytes;
    var result = List<int>.from(block);
    
    for (var i = 1; i < iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    
    return base64UrlEncode(result);
  }
}

