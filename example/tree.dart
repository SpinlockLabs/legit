import "package:legit/legit.dart";

void main() {
  var git = new GitClient.forCurrentDirectory();

  git.listTree("HEAD").then((files) {
    for (var file in files) {
      print(file.path);
    }
  });
}
