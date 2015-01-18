part of legit;

class GitCommit {
  final GitClient git;

  GitCommit(this.git);

  String sha;
  String treeSha;
  String message;
  GitAuthor author;
  DateTime authoredAt;
  DateTime committedAt;
  GitAuthor committer;
  
  String get prettySha => new List.generate(sha.length, (i) => sha[i]).take(10).join();
}

class GitAuthor {
  final GitClient git;
  GitAuthor(this.git);

  String name;
  String email;

  @override
  String toString() => "${name} <${email}>";
}
