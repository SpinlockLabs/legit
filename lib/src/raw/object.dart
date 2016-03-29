part of legit.raw;

class GitRawObject {
  final String type;
  final Uint8List data;

  GitRawObject(this.type, this.data);

  factory GitRawObject.text(String type, String content) {
    Uint8List data = new Uint8List.fromList(
      const Utf8Encoder().convert(content)
    );
    return new GitRawObject(type, data);
  }

  String get hash {
    return _hash != null ? _hash : _hash = hashByteListSha1(encode(false));
  }

  String _hash;
  Uint8List _encoded;

  Uint8List encode([bool compress = true]) {
    if (_encoded == null) {
      String header = "${type} ${data.length}\u0000";
      Uint8List headerData = new Uint8List.fromList(
        const Utf8Encoder().convert(header)
      );

      Uint8List out = new Uint8List(headerData.length + data.length);
      int i = 0;
      while (i < headerData.length) {
        out[i] = headerData[i];
        i++;
      }

      while (i < out.length) {
        out[i] = data[i - headerData.length];
        i++;
      }

      _encoded = out;
    }

    if (compress) {
      var result = ZLIB.encode(_encoded);
      if (result is! Uint8List) {
        result = new Uint8List.fromList(result);
      }
      return result;
    } else {
      return _encoded;
    }
  }

  static GitRawObject decode(Uint8List input) {
    try {
      var decompressed = ZLIB.decode(input);
      if (decompressed is! Uint8List) {
        decompressed = new Uint8List.fromList(decompressed);
      }
      input = decompressed;
    } catch (e) {}

    var i = 0;
    for (var b in input) {
      if (b == 0) {
        break;
      }
      i++;
    }

    List<int> headerBytes = input.sublist(0, i);
    String header = const Utf8Decoder(allowMalformed: true).convert(headerBytes);
    List<String> headerParts = header.split(" ");
    String type = headerParts[0];
    int len = int.parse(headerParts[1]);
    Uint8List data = new Uint8List(len);
    i++;
    for (var x = i; x < input.length; x++) {
      data[x - i] = input[x];
    }
    return new GitRawObject(type, data);
  }

  String decodeText() {
    return const Utf8Decoder(allowMalformed: true).convert(data);
  }
}
