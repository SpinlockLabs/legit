import "dart:async";
import "dart:io";

import "package:legit/legit.dart";

main() async {
  await GitClient.handleConfigure(handle, logHandler: print);
}

handle() async {
  var git = await GitClient.openOrCloneRepository(
    "https://github.com/DirectMyFile/legit-test.git",
    "test"
  );

  var counter = await incrementCounterFile(
    git.getRealFile("counter")
  );
  await git.checkout("tmp", create: true);
  await git.add("counter");
  await git.commit("Increment Counter to ${counter}");
  await git.checkout("master");
  await git.merge("tmp");
  await git.deleteBranch("tmp");
  await git.push();
  await git.delete();
}

Future<int> incrementCounterFile(File file) async {
  if (!(await file.exists())) {
    await file.writeAsString("0");
  }
  var content = await file.readAsString();
  var number = int.parse(content);
  number++;
  await file.writeAsString(number.toString());
  return number;
}
