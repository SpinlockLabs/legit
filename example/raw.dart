import "package:legit/legit.dart";
import "package:legit/raw.dart";

main() async {
  var git = new GitClient.forCurrentDirectory();
  for (String id in await git.listObjects()) {
    var a = id.substring(0, 2);
    var b = id.substring(2);
    var file = git.getRealFile(".git/objects/${a}/${b}");
    if (!(await file.exists())) {
      continue;
    }
    var bytes = await file.readAsBytes();
    var object = GitRawObject.decode(bytes);
    if (object.type == "commit") {
      try {
        print("${object.hash}");
      } catch (e) {}
    }
  }
}
