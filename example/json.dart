import "dart:io";
import "dart:convert";

import "package:legit/legit.dart";

main() async {
  await GitClient.handleConfigure(handle, inherit: false);
}

handle() async {
  var git = await GitClient.openOrCloneRepository(
    "git://github.com/git/git.git",
    "repositories/git"
  );

  var json = <String, dynamic>{};
  var refs = json["refs"] = <dynamic>[];
  var commits = json["commits"] = <dynamic>[];

  for (GitRef ref in await git.listRefs()) {
    var map = <String, dynamic>{
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

  for (GitCommit commit in await git.listCommits()) {
    commits.add(serializeCommit(commit));
  }

  var file = new File("repositories/git.json");
  await file.writeAsString(
    const JsonEncoder.withIndent("  ").convert(json) + "\n"
  );
}

Map<String, dynamic> serializeCommit(GitCommit commit) {
  return <String, dynamic>{
    "sha": commit.sha,
    "message": commit.message,
    "author": {
      "name": commit.author.name,
      "email": commit.author.email
    }
  };
}
