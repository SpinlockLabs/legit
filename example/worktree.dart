import "dart:async";
import "dart:io";

import "package:legit/legit.dart";
import "package:legit/id.dart";

main() async {
  await GitClient.handleConfigure(handle, logHandler: print);
}

handle() async {
  var gitA = await GitClient.openOrCloneRepository(
    "https://github.com/DirectMyFile/legit-test.git",
    "test"
  );

  var id = await generateStrongToken();
  var git = await gitA.createWorktree("../tmp", branch: id);

  var counter = await incrementCounterFile(
    git.getRealFile("counter")
  );
  await git.add("counter");
  await git.commit("Increment Counter to ${counter}");
  await git.delete();
  await gitA.pruneWorktrees();
  await gitA.deleteBranch(id, force: true);
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
