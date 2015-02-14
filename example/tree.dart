import "package:legit/legit.dart";

void main() {
  var git = new GitClient();

  git.listTree("HEAD").then((files) {
    print(files.join("\n"));
  });
}
