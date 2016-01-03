part of legit;

class GitRef {
  final GitClient git;

  GitRef(this.git);

  String commitSha;
  String type;
  String ref;

  bool get isTag => type == "tag" || ref.startsWith("refs/tags/");
  bool get isCommit => type == "commit" && !ref.startsWith("refs/tags/");

  String get remote {
    if (!ref.startsWith("refs/remotes/")) {
      return null;
    } else {
      return ref.split("/")[2];
    }
  }

  String get name => ref.split("/").last;

  Future<GitCommit> fetchCommit() => git.getCommit(commitSha);
}
