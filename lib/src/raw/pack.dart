part of legit.raw;

//class GitPackObject {
//  int type;
//  int size;
//  Uint8List content;
//
//  GitRawObject _raw;
//
//  bool get isCommit => type == 1;
//  bool get isTree => type == 2;
//  bool get isBlob => type == 3;
//  bool get isTag => type == 4;
//  bool get isOfsDelta => type == 6;
//  bool get isRefDelta => type == 7;
//
//  GitRawObject asRawObject() {
//    if (_raw != null) {
//      return _raw;
//    }
//
//    var object = new GitRawObject(typeName, content);
//    _raw = object;
//    return object;
//  }
//
//  String get typeName {
//    if (isCommit) {
//      return "commit";
//    } else if (isTree) {
//      return "tree";
//    } else if (isBlob) {
//      return "blob";
//    } else if (isTag) {
//      return "tag";
//    } else if (isOfsDelta) {
//      return "ofs-delta";
//    } else if (isRefDelta) {
//      return "ref-delta";
//    }
//    return "unknown";
//  }
//}
//
//class GitRawPackReader {
//  static const int SUPPORTED_VERSION = 2;
//
//  final ByteData input;
//
//  List<GitPackObject> _objects = [];
//  Map<int, String> _offsets = {};
//
//  int _count;
//
//  GitRawPackReader(this.input);
//
//  factory GitRawPackReader.fromBytes(Uint8List input) {
//    return new GitRawPackReader(input.buffer.asByteData());
//  }
//
//  List<GitPackObject> decode() {
//    _validateHeader();
//    _validateVersion();
//
//    _count = readInt32();
//
//    for (var i = 1; i <= _count; i++) {
//      _readObject();
//    }
//
//    var tmp = _objects;
//    _objects = [];
//    return tmp;
//  }
//
//  int readUint8() {
//    if (_offset >= input.lengthInBytes) {
//      return -1;
//    }
//
//    int b = input.getUint8(_offset);
//    _offset += 1;
//    return b;
//  }
//
//  int readInt32() {
//    int b = input.getInt32(_offset);
//    _offset += 4;
//    return b;
//  }
//
//  Uint8List readUint8List(int len, {bool optimistic: false}) {
//    var buff = new Uint8List(len);
//    for (var i = 0; i < len; i++) {
//      var b = readUint8();
//      if (b == -1) {
//        if (optimistic) {
//          break;
//        } else {
//          throw new Exception("Unable to read ${len} bytes.");
//        }
//      } else {
//        buff[i] = b;
//      }
//    }
//    return buff;
//  }
//
//  void _validateHeader() {
//    var str = const Utf8Decoder(allowMalformed: true)
//      .convert(readUint8List(4));
//    if (str != "PACK") {
//      throw new Exception(
//        "Failed to validate pack header."
//        " Expected 'PACK', but got ${str}");
//    }
//  }
//
//  void _readObject() {
//    int start = _offset;
//    int type;
//    int size;
//    int steps = 0;
//    int buf = readUint8();
//
//    {
//      type = (buf >> 4) & 7;
//      size = buf & 0xf;
//      steps++;
//    }
//
//    var shift = 4;
//
//    while ((buf & 0x80) == 0x80) {
//      buf = readUint8();
//
//      if (buf == -1) {
//        break;
//      }
//
//      size |= (buf & 0x7f) << shift;
//      steps++;
//      shift += 7;
//    }
//
//    size = (size & 0xFFFFFFFF) >> 0;
//
//    if (type > 0 && type <= 4) {
//      var obj = new GitPackObject();
//      obj
//        ..type = type
//        ..size = size;
//
//      var content = readUint8List(size, optimistic: true);
//
//      if (type > 0 && type <= 4) {
//        try {
//          content = asUint8List(ZLIB.decode(content));
//        } catch (e) {}
//      }
//
//      obj.content = content;
//
//      _objects.add(obj);
//    } else if (type == 7) {
//      var data = readUint8List(20, optimistic: true);
//      var ref = decodeHashFromBytes(data);
//      data = readUint8List(size, optimistic: true);
//      _readRefDelta(ref, data);
//    } else {
//      readUint8List(size, optimistic: true);
//    }
//  }
//
//  void _validateVersion() {
//    var version = readInt32();
//    if (version > SUPPORTED_VERSION) {
//      throw new Exception(
//        "Failed to decode pack."
//        " Pack is version ${version} but we only"
//        " support <=${SUPPORTED_VERSION}.");
//    }
//  }
//
//  int _offset = 0;
//}
