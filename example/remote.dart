import "package:legit/legit.dart";

void main() {
  var git = new GitClient.forCurrentDirectory();

  git.listRemoteRefs().then((refs) {
    for (var ref in refs) {
      print(ref.ref);
    }
  });
}
