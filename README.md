# Legit

Legit is a Git Library for Dart.

## Examples

### List Commits

```dart
import "package:legit/legit.dart";

main() async {
  var git = new GitClient.forCurrentDirectory();

  var commits = await git.listCommits();
  for (var commit in commits) {
    print("- " + commit.message);
    print("  By: ${commit.author.name} <${commit.author.email}>");
    print("  SHA: ${commit.sha}");
  }
}
```
