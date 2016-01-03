import "package:legit/legit.dart";

main() async {
  await GitClient.handleConfigure(handle);
}

handle() async {
  var git = new GitClient.forCurrentDirectory();
  var patch = await git.createPatch("HEAD~3..HEAD");
  print(patch);
}
