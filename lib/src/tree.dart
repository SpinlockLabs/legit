part of legit;

class GitTreeFile {
  final String blob;
  final String path;

  GitTreeFile(this.blob, this.path);
  
  String get name => path.split(Platform.pathSeparator).last;
}
