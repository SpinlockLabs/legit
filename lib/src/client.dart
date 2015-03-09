part of legit;

class GitClient {
  final Directory directory;
  bool quiet = false;

  GitClient([Directory dir]) : directory = (dir == null ? Directory.current : dir);

  Future<bool> clone(String url, {String branch, bool bare: false, bool mirror: false, bool recursive: false}) {
    var args = ["clone", url];

    if (branch != null) {
      args.addAll(["-b", branch]);
    }

    if (bare) {
      args.add("--bare");
    }

    if (mirror) {
      args.add("--mirror");
    }

    if (recursive) {
      args.add("--recursive");
    }

    args.add(directory.path);

    return execute(args).then((code) => code == GitExitCodes.OK);
  }
  
  Future<String> hashObject(content, {String type, bool write: true}) {
    if (content is! String && content is! List<int>) {
      throw new ArgumentError("Invalid Content");
    }
    
    var args = ["hash-object", "--stdin"];
    
    if (write) {
      args.add("-w");
    }
    
    var buff = new StringBuffer();
    
    return executeSpawn(args).then((process) {
      process.stdin.write(content);
      process.stdin.close();
      
      process.stdout.transform(UTF8.decoder).listen((data)=> buff.write(data));
      
      return process.exitCode;
    }).then((code) {
      if (code != 0) {
        throw new GitException("Failed to hash object.");
      } else {
        return buff.toString().trim();
      }
    });
  }
  
  Future<String> createPatch(String ref) {
    return executeResult(["format-patch", ref, "--stdout"]).then((result) {
      if (result.exitCode != GitExitCodes.OK) {
        throw new GitException("Failed to generate patch.");
      }
      
      return result.stdout;
    });
  }
  
  Future<String> createDiff(String from, String to) {
    return executeResult(["diff", from, to]).then((result) => result.stdout);
  }

  Future<List<GitTreeFile>> listTree(String ref) {
    return executeResult(["ls-tree", "--full-tree", "-r", ref]).then((result) {
      if (result.exitCode != 0) throw new GitException("Failed to list tree.");
      var content = result.stdout;
      var lines = content.split("\n");
      return lines
          .map((it) => it.replaceAll("\t", " "))
          .map((it) => it.trim())
          .map((it) => it.split(" ")..removeWhere((m) {
            return m.trim().isEmpty;
          }))
          .where((it) => it.isNotEmpty)
          .map((it) {
            return new GitTreeFile(it[2], it[3]);
          }).toList();
    });
  }
  
  Future<List<int>> getBinaryBlob(String blob) {
    return executeResult(["cat-file", "blob", blob], binary: true).then((result) {
      if (result.exitCode != 0) {
        throw new Exception("Blob not Found");
      }
      
      return result.stdout;
    });
  }
  
  Future<String> getTextBlob(String blob) {
    return getBinaryBlob(blob).then((content) => UTF8.decode(content));
  }

  Future<GitCommit> commit(String message) {
    var args = ["commit", "-m", message];

    return executeResult(args).then((result) {
      if (result.exitCode != 0) {
        return null;
      } else {
        return listCommits(limit: 1);
      }
    }).then((commits) {
      if (commits == null) {
        return null;
      } else {
        return commits[0];
      }
    });
  }

  Future<List<GitCommit>> listCommits({int limit, String range, String file}) {
    var args = ["log", "--format=format:%H%n%T%n%aN%n%aE%n%cN%n%cE%n%ai%n%ci%n%B%n%n%n%n", "--no-color"];

    if (limit != null) {
      args.add("--max-count=${limit}");
    }

    if (range != null) {
      args.add(range);
    }
    
    if (file != null) {
      args.addAll(["--", file]);
    }

    return executeResult(args).then((result) {
      if (result.exitCode != 0) {
        return null;
      } else {
        String output = result.stdout;
        var commits = [];
        List<String> clines = output.split("\n\n\n\n\n").map((it) => it.trim()).toList();
        clines.removeWhere((it) => it.isEmpty || !it.contains("\n"));
        for (var line in clines) {
          var parts = line.split("\n");
          var commit = new GitCommit(this);
          commit.sha = parts[0];
          commit.treeSha = parts[1];
          commit.author = new GitAuthor(this)
              ..name = parts[2]
              ..email = parts[3];
          commit.committer = new GitAuthor(this)
              ..name = parts[4]
              ..email = parts[5];
          commit.authoredAt = DateTime.parse(parts[6]);
          commit.committedAt = DateTime.parse(parts[7]);
          commit.message = parts.getRange(8, parts.length).join("\n");
          commits.add(commit);
        }
        return commits;
      }
    });
  }

  Future<GitMergeResult> merge(String ref, {String into, String message, bool fastForward: false, bool fastForwardOnly: false, String strategy}) {
    var args = ["merge"];

    if (message != null) {
      args.addAll(["-m", message]);
    }
    
    if (fastForward) {
      args.add("--ff");
    }
    
    if (fastForwardOnly) {
      args.add("--ff-only");
    }

    if (into != null) {
      args.add(into);
    }
    
    if (strategy != null) {
      args.add("--strategy=${strategy}");  
    }

    args.add(ref);

    return executeResult(args).then((proc) {
      var result = new GitMergeResult();
      result.code = proc.exitCode;
      if (result.code == 1 && proc.stdout.toString().contains("CONFLICT")) {
        result.conflicts = true;
      }
      return result;
    });
  }
  
  Future<bool> filterBranch(String ref, String command) {
    return execute(["filter-branch", command, ref]).then((code) => code == GitExitCodes.OK);
  }
  
  Future<String> writeTree() {
    return executeResult(["write-tree"]).then((result) {
      if (result.exitCode != GitExitCodes.OK) {
        throw new GitException("Failed to write tree.");
      }
      
      return result.stdout.trim();
    });
  }
  
  Future<bool> updateServerInfo() {
    return execute(["update-server-info"]).then((code) => code == GitExitCodes.OK);
  }

  Future<bool> push({String remote: "origin", String branch: "HEAD"}) {
    return execute(["push", remote, branch]).then((code) => code == GitExitCodes.OK);
  }

  Future<bool> pull({bool all: true}) {
    var args = ["pull"];
    if (all) {
      args.add("--all");
    }
    return execute(args).then((code) => code == GitExitCodes.OK);
  }

  Future<bool> abortMerge() {
    return execute(["merge", "--abort"]).then((code) => code == GitExitCodes.OK);
  }
  
  Future<bool> cherryPick(String commit) {
    return execute(["cherry-pick", commit]).then((code) => code == 0);
  }
  
  Future<bool> abortCherryPick() {
    return execute(["cherry-pick", "--abort"]).then((code) => code == 0);
  }
  
  Future<bool> quitCherryPick() {
    return execute(["cherry-pick", "--quit"]).then((code) => code == 0);
  }

  Future<bool> checkout(String branch, {bool create: false, String from}) {
    var args = ["checkout"];

    if (create) {
      args.add("-b");
    }

    args.add(branch);

    if (from != null) {
      args.add(from);
    }

    return execute(args).then((code) => code == GitExitCodes.OK);
  }

  bool add(String path) {
    return executeSync(["add", path]).exitCode == GitExitCodes.OK;
  }

  bool rm(String path, {bool recursive: false, bool force: false}) {
    var args = ["rm"];

    if (recursive) {
      args.add("-r");
    }

    if (force) {
      args.add("-f");
    }

    args.add(path);
    return Process.runSync("git", args, workingDirectory: directory.path).exitCode == GitExitCodes.OK;
  }

  bool hasRemote(String remote) {
    return Process.runSync("git", ["remote"], workingDirectory: directory.path).stdout.split(" ").contains(remote);
  }

  Future<bool> isRepository() {
    return execute(["status"]).then((code) {
      return code == GitExitCodes.STATUS_NOT_A_GIT_REPOSITORY;
    });
  }

  Future<bool> rebase(String branch, {String onto, String upstream}) {
    var args = ["rebase"];

    if (onto != null) {
      args.addAll(["--onto", onto]);
    }

    if (upstream != null) {
      args.add(upstream);
    }

    args.add(branch);

    return execute(args).then((code) {
      return code == GitExitCodes.OK;
    });
  }

  Future<bool> revert(String commit) {
    var args = ["revert", commit];
    
    return execute(args).then((code) {
      return code == GitExitCodes.OK;
    });
  }

  Future<bool> clean({String path, bool directories: false, bool force: false}) {
    var args = ["clean"];

    if (path != null) {
      args.add(path);
    }

    if (directories) {
      args.add("-d");
    }

    if (force) {
      args.add("-f");
    }

    return execute(args).then((code) {
      return code == GitExitCodes.OK;
    });
  }

  Future<bool> gc({bool aggressive: false, bool auto: false, bool force: false}) {
    var args = ["gc"];

    if (aggressive) {
      args.add("--aggressive");
    }

    if (auto) {
      args.add("--auto");
    }

    if (force) {
      args.add("--force");
    }

    return execute(args).then((code) {
      return code == GitExitCodes.OK;
    });
  }

  bool mv(String path, String destination) {
    return executeSync(["mv", path, destination]).exitCode == GitExitCodes.OK;
  }

  String currentBranch() {
    return executeSync(["rev-parse", "--abbrev-ref", "HEAD"]).stdout.trim();
  }

  Future<String> parseRev(String input, {bool abbrevRef: false}) {
    var args = ["rev-parse"];

    if (abbrevRef) {
      args.add("--abbrev-ref");
    }

    args.add(input);
    return executeResult(args).then((result) {
      if (result.exitCode != 0) {
        throw new InvalidRevException(input);
      } else {
        return stripNewlines(result.stdout);
      }
    });
  }

  Future<bool> fetch(String remote) {
    return execute(["fetch", remote]).then((code) {
      return code == GitExitCodes.OK;
    });
  }

  Future<bool> addRemote(String name, String url) {
    return execute(["remote", "add", name, url]).then((code) {
      return code == GitExitCodes.OK;
    });
  }

  Future<bool> removeRemote(String name) {
    return execute(["remote", "remove", name]).then((code) {
      return code == GitExitCodes.OK;
    });
  }

  Future<bool> createBranch(String name, {String from}) {
    var args = ["branch", name];
    if (from != null) {
      args.add(from);
    }
    return execute(args).then((code) {
      return code == GitExitCodes.OK;
    });
  }
  
  Future<bool> fsck({bool full: false, bool strict: false}) {
    var args = ["fsck"];
    
    if (full) {
      args.add("--full");
    }
    
    if (strict) {
      args.add("--strict");
    }
    
    return executeResult(args).then((result) => result.exitCode == 0);
  }
  
  Future<List<GitRef>> listRemoteRefs({String url}) {
    return executeResult(["ls-remote"]..addAll(url != null ? [url] : [])).then((result) {
      List<String> refLines = result.stdout.split("\n");
      var refs = [];
      for (var line in refLines) {
        if (line.trim().isEmpty) continue;

        var ref = new GitRef(this);

        var parts = line.split(new RegExp(r"\t| "))..removeWhere((it) => it.trim().isEmpty);

        ref.commitSha = parts[0];
        ref.ref = parts[1];

        refs.add(ref);
      }

      return refs;
    });
  }

  Future<List<String>> listBranches({String remote}) {
    return listRefs().then((refs) {
      return refs.where((it) {
        return it.remote == remote && it.isCommit;
      });
    }).then((refs) {
      return refs.map((it) => it.name).toList();
    });
  }

  Future<List<GitRef>> listRefs() {
    return executeResult(["for-each-ref"]).then((result) {
      List<String> refLines = result.stdout.split("\n");
      var refs = [];
      for (var line in refLines) {
        if (line.trim().isEmpty) continue;

        var ref = new GitRef(this);

        var parts = line.split(" ");

        ref.commitSha = parts[0];
        ref.type = parts[1];
        ref.ref = parts[2];

        refs.add(ref);
      }

      return refs;
    });
  }

  Future<bool> createTag(String name, {String commit}) {
    var args = ["tag", name];
    if (commit != null) {
      args.add(commit);
    }
    return execute(args).then((code) {
      return code == GitExitCodes.OK;
    });
  }

  Future<List<String>> listTags() {
    return listRefs().then((refs) {
      return refs.where((it) => it.isTag).map((it) => it.name).toSet().toList();
    });
  }

  Future<bool> deleteTag(String name) {
    return execute(["tag", "-d", name]).then((code) {
      return code == GitExitCodes.OK;
    });
  }

  Future<bool> deleteBranch(String name) {
    return execute(["branch", "-d", name]).then((code) {
      return code == GitExitCodes.OK;
    });
  }
  
  Future<Process> executeSpawn(List<String> args) {
    return Process.start("git", args, workingDirectory: directory.path);
  }

  Future<int> execute(List<String> args) {
    return Process.start("git", args, workingDirectory: directory.path).then((process) {
      if (!quiet) {
        inheritIO(process, lineBased: false);
      }
      return process.exitCode;
    });
  }

  Future<ProcessResult> executeResult(List<String> args, {bool binary: false}) {
    return Process.run("git", args, workingDirectory: directory.path, stdoutEncoding: binary ? null : SYSTEM_ENCODING);
  }
  
  ProcessResult executeSync(List<String> args) {
    return Process.runSync("git", args, workingDirectory: directory.path);
  }
  
  Future<bool> pushMirror(String url) {
    return execute(["push", "--mirror", url]).then((code) {
      return code == GitExitCodes.OK;
    });
  }
  
  Future<bool> init({bool bare: false}) {
    return execute(["init"]..addAll(bare ? ["--bare"] : [])).then((code) => code == GitExitCodes.OK);
  }

  Future<GitCommit> getCommit(String commitSha) {
    return listCommits(limit: 1, range: commitSha).then((commits) => commits.first);
  }
}
