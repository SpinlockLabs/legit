part of legit;

class GitCommitChange {
  String name;
  String change;

  GitCommitChange(this.name, this.change);
}

class GitCommit {
  final GitClient git;

  GitCommit(this.git);

  String sha;
  String treeSha;
  String message;
  List<String> decorates;
  GitAuthor author;
  DateTime authoredAt;
  DateTime committedAt;
  GitAuthor committer;

  List<GitCommitChange> changes;

  void setDecorate(String str) {
    if (str.length > 2) {
      decorates = str.substring(str.indexOf('(') + 1, str.lastIndexOf(')')).split(', ');
    } else {
      decorates = null;
    }
  }

  String get prettySha => new List<String>.generate(10, (i) => sha[i]).join();
}

class GitAuthor {
  final GitClient git;

  GitAuthor(this.git);

  String name;
  String email;

  @override
  String toString() => "${name} <${email}>";
}
