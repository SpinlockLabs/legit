import "package:legit/legit.dart";

void main() {
  var git = new GitClient();

  git.listTree("HEAD").then((files) {
    return files.where((file) => file.name.endsWith(".dart")).map((it) => it.blob).toList();
  }).then((blobs) {
    return git.getTextBlob(blobs[0]);
  }).then((content) {
    print(content);
  });
}
