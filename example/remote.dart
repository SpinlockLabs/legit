import "package:legit/legit.dart";

void main() {
  var git = new GitClient();

  git.listRemoteRefs().then((refs) {
    for (var ref in refs) {
      print(ref.ref);
    }
  });
}
