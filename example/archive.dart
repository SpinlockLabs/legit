import "package:legit/legit.dart";

main() async {
  await GitClient.handleConfigure(handle, logHandler: print);
}

handle() async {
  var git = new GitClient.forCurrentDirectory();
  var file = git.getRealFile("test.tgz");
  var bytes = await git.createArchive("HEAD", "tgz");
  await file.writeAsBytes(bytes);
}
