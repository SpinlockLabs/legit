part of legit;

enum GitListFilesType {
  CACHED,
  DELETED,
  MODIFIED,
  OTHERS,
  IGNORED,
  STAGE,
  UNMERGED,
  KILLED
}

class GitTreeFile {
  final String blob;
  final String path;

  GitTreeFile(this.blob, this.path);

  String get name => path.split("/").last;
}
