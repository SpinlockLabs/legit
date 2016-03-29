//import "dart:io";
//
//import "package:legit/raw.dart";
//
//main() async {
//  var dir = new Directory(".git/objects/pack");
//
//  await for (FileSystemEntity entity in dir.list()) {
//    if (entity is! File || !entity.path.split("/").last.endsWith(".pack")) {
//      continue;
//    }
//
//    var bytes = await (entity as File).readAsBytes();
//    var reader = new GitRawPackReader.fromBytes(bytes);
//    var objects = reader.decode();
//
//    for (GitPackObject entry in objects) {
//      print(entry.typeName);
//    }
//  }
//}
