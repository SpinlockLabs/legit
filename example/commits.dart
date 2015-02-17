import "package:legit/legit.dart";

void main() {
  var git = new GitClient();

  git.listCommits().then((commits) {
    for (var commit in commits) {
      print("- " + commit.message);
      print("  By: ${commit.author.name} <${commit.author.email}>");
      print("  SHA: ${commit.sha}");
    }
  });
}
