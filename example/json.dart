import "dart:io";
import "dart:convert";

import "package:legit/legit.dart";

main() async {
  await GitClient.handleProcess(handle, inherit: false);
}

handle() async {
  var git = await GitClient.openOrCloneRepository(
    "git://github.com/git/git.git",
    "repositories/git"
  );

  var json = {};
  var refs = json["refs"] = [];

  for (GitRef ref in await git.listRefs()) {
    var map = {
      "name": ref.name,
      "type": ref.type
    };

    if (ref.isCommit) {
      map["commit"] = serializeCommit(await ref.fetchCommit());
    }

    if (ref.remote != null) {
      map["remote"] = ref.remote;
    }

    if (ref.isTag) {
      map["sha"] = ref.commitSha;
    }

    refs.add(map);
  }

  var file = new File("repositories/git.json");
  await file.writeAsString(
    const JsonEncoder.withIndent("  ").convert(json) + "\n"
  );
}

Map serializeCommit(GitCommit commit) {
  return {
    "sha": commit.sha,
    "message": commit.message,
    "author": {
      "name": commit.author.name,
      "email": commit.author.email
    }
  };
}
