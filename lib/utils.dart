library legit.utils;

import "package:crypto/crypto.dart";

import "dart:typed_data";
import "dart:convert";

bool onlyOneTrue(List<bool> inputs) {
  return inputs.where((it) => it).length == 1;
}

String stripNewlines(String input) => input.replaceAll("\n", "");


String get currentTimestamp {
  return new DateTime.now().toString();
}

String hashByteListSha1(Uint8List data) {
  var sha = new SHA1();
  sha.add(data);
  return CryptoUtils.bytesToHex(sha.close());
}

String decodeHashFromBytes(Uint8List data) {
  return CryptoUtils.bytesToHex(data.getRange(0, 19));
}

Uint8List byteSubData(Uint8List data, int start) {
  var i = 0;
  var x = start;

  var out = new Uint8List(data.lengthInBytes - start);
  while (x < data.lengthInBytes) {
    data[i] = data[x];
    i++;
    x++;
  }
  return out;
}

Uint8List asUint8List(input) {
  if (input is String) {
    return asUint8List(const Utf8Encoder().convert(input));
  } else if (input is Uint8List) {
    return input;
  } else if (input is TypedData) {
    return input.buffer.asUint8List();
  } else if (input is List) {
    return new Uint8List.fromList(input);
  } else if (input is Iterable) {
    return new Uint8List.fromList(input.toList());
  } else {
    throw new Exception("Can't take bytes out of ${input}.");
  }
}
