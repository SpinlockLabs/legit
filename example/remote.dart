import "package:legit/legit.dart";

main() async {
  var git = new GitClient.forCurrentDirectory();
  var refs = await git.listRemoteRefs();

  for (var ref in refs) {
    print(ref.ref);
  }
}
