part of legit;

class GitClient {
  static final RegExp _TAB_SPACE = new RegExp(r"\t| ");

  final Directory directory;

  factory GitClient.forPath(String path) {
    var dir = new Directory(path);
    return new GitClient.forDirectory(dir);
  }

  factory GitClient.forCurrentDirectory() {
    return new GitClient.forDirectory(Directory.current);
  }

  factory GitClient.forDirectory(Directory dir) {
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return new GitClient._(dir.absolute);
  }

  GitClient._(this.directory);

  static GitClient open(String path) {
    return new GitClient.forPath(path);
  }

  static Future<GitClient> openOrCloneRepository(String url, String path, {
    bool bare: false
  }) async {
    var client = new GitClient.forPath(path);
    if (await client.directory.exists() && await client.isRepository()) {
      return client;
    } else {
      return await cloneRepositoryTo(url, path, bare: bare);
    }
  }

  static Future<GitClient> cloneRepositoryTo(String url, String path, {
    bool bare: false,
    bool recursive: false,
    bool mirror: false,
    bool overwrite: false
  }) async {
    var client = new GitClient.forPath(path);

    if (overwrite) {
      if (await client.directory.exists()) {
        await client.directory.delete(recursive: true);
        await client.directory.create(recursive: true);
      }
    }

    await client.clone(
      url,
      bare: bare,
      mirror: mirror,
      recursive: recursive
    );
    return client;
  }

  Future clone(String url, {
    String branch,
    bool bare: false,
    bool mirror: false,
    bool recursive: false,
    int depth,
    bool checkout: true,
    String reference,
    bool local: false,
    bool dissociate: false
  }) async {
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

    if (depth != null) {
      args.add("--depth=${depth}");
    }

    if (!checkout) {
      args.add("--no-checkout");
    }

    if (reference != null) {
      args.addAll(["--reference", reference]);
    }

    if (local) {
      args.add("--local");
    }

    if (dissociate) {
      args.add("--dissociate");
    }

    args.add(directory.path);

    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to clone ${url} with options [${args.skip(1).join(", ")}]"
    );
  }

  Future<String> hashObject(content, {
    String type,
    bool write: true
  }) async {
    if (content is! String && content is! List<int>) {
      throw new ArgumentError("Invalid Content");
    }

    var args = ["hash-object", "--stdin"];

    if (write) {
      args.add("-w");
    }

    var result = await execute(args);

    int code = result.exitCode;

    if (code != 0) {
      throw new GitException("Failed to hash object.");
    } else {
      return result.stdout.toString();
    }
  }

  Future<String> createPatch(String ref) async {
    var args = ["format-patch", ref, "--stdout"];
    var result = await execute(args);
    checkError(result.exitCode, "Failed to generate patch.");
    return result.stdout;
  }

  Future<String> createDiff(String from, String to) async {
    var args = ["diff", from, to];
    var result = await execute(args);
    checkError(result.exitCode, "Failed to generate diff.");
    return result.stdout.toString();
  }

  Future<List<String>> listFiles({GitListFilesType type}) async {
    var args = ["ls-files"];
    if (type != null) {
      var name = type.toString().split(".").last.toLowerCase();
      args.add("--${name}");
    }
    var result = await execute(args);
    checkError(result.exitCode, "Failed to list files.");
    return result.stdout.toString().split("\n").where((x) {
      return x.trim().isEmpty;
    }).toList();
  }

  Future<List<GitTreeFile>> listTree(String ref) async {
    var args = ["ls-tree", "--full-tree", "-r", ref];
    var result = await execute(args);
    if (result.exitCode != 0) {
      throw new GitException("Failed to list tree.");
    }
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
  }

  Future<List<int>> getBinaryBlob(String blob) {
    return execute(["cat-file", "blob", blob], binary: true).then((result) {
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

    return execute(args).then((result) {
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

  Future<List<GitCommit>> listCommits({int limit, String range, String file}) async {
    var args = [
      "log",
      "--format=format:%H%n%T%n%aN%n%aE%n%cN%n%cE%n%ai%n%ci%n%B%n%n%n%n",
      "--no-color"
    ];

    if (limit != null) {
      args.add("--max-count=${limit}");
    }

    if (range != null) {
      args.add(range);
    }

    if (file != null) {
      args.addAll(["--", file]);
    }

    BetterProcessResult result = await execute(args);

    if (result.exitCode != 0) {
      return null;
    } else {
      String output = result.stdout.toString();
      var commits = [];
      List<String> clines = output.split("\n\n\n\n\n")
        .map((it) => it.trim())
        .toList();
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
  }

  Future<GitMergeResult> merge(String ref, {
    String into,
    String message,
    bool fastForward: false,
    bool fastForwardOnly: false,
    String strategy
  }) async {
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

    BetterProcessResult proc = await execute(args);
    var result = new GitMergeResult();
    result.code = proc.exitCode;
    if (result.code != 0 && proc.stdout.toString().contains("CONFLICT")) {
      result.conflicts = true;
    }
    return result;
  }

  Future filterBranch(String ref, String command) async {
    var args = ["filter-branch", command, ref];
    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to filter-branch with command ${command} and ref ${ref}"
    );
  }

  Future<String> writeTree() async {
    var result = await execute(["write-tree"]);

    checkError(result.exitCode, "Failed to write-tree.");

    return result.stdout.trim();
  }

  Future updateServerInfo() async {
    var args = ["update-server-info"];
    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to update server info."
    );
  }

  Future push({String remote: "origin", String branch: "HEAD"}) async {
    var args = ["push", remote, branch];
    var result = await execute(args);
    checkError(result.exitCode, "Failed to push ${branch} to ${remote}");
  }

  Future pull({bool all: true}) async {
    var args = ["pull"];
    if (all) {
      args.add("--all");
    }
    var result = await execute(args);
    checkError(result.exitCode, "Failed to pull.");
  }

  Future abortMerge() async {
    var args = ["merge", "--abort"];
    var result = await execute(args);
    checkError(result.exitCode, "Failed to abort merge.");
  }

  Future<GitMergeResult> cherryPick(String commit) async {
    var args = ["cherry-pick", commit];
    BetterProcessResult r = await execute(args);
    var result = new GitMergeResult();
    result.code = r.exitCode;
    if (result.code != 0 && r.stdout.toString().contains("CONFLICT")) {
      result.conflicts = true;
    }
    return result;
  }

  Future abortCherryPick() async {
    var args = ["cherry-pick", "--abort"];
    var result = await execute(args);
    checkError(result.exitCode, "Failed to abort cherry pick.");
  }

  Future quitCherryPick() async {
    var args = ["cherry-pick", "--quit"];
    var result = await execute(args);
    checkError(result.exitCode, "Failed to quit cherry pick.");
  }

  Future checkout(String branch, {bool create: false, String from}) async {
    var args = ["checkout"];

    if (create) {
      args.add("-b");
    }

    args.add(branch);

    if (from != null) {
      args.add(from);
    }

    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to checkout ${branch}."
    );
  }

  Future add([String path = "."]) async {
    var args = ["add", directory.path];
    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to add ${path}."
    );
  }

  Future rm(String path, {bool recursive: false, bool force: false}) async {
    var args = ["rm"];

    if (recursive) {
      args.add("-r");
    }

    if (force) {
      args.add("-f");
    }

    args.add(path);
    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to add ${path}."
    );
  }

  Future<bool> hasRemote(String remote) async {
    var result = await execute(["remote"]);
    return result.stdout.toString().split(_TAB_SPACE).contains(remote);
  }

  Future<bool> isRepository() async {
    var code = await executeSimple(["status"]);
    return code != GitExitCodes.STATUS_NOT_A_GIT_REPOSITORY;
  }

  Future rebase(String branch, {String onto, String upstream}) async {
    var args = ["rebase"];

    if (onto != null) {
      args.addAll(["--onto", onto]);
    }

    if (upstream != null) {
      args.add(upstream);
    }

    args.add(branch);

    var result = await execute(args);
    checkError(result.exitCode, "Failed to rebase ${branch}.");
  }

  Future revert(String commit) async {
    var args = ["revert", commit];

    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to revert ${commit}."
    );
  }

  Future clean({String path, bool directories: false, bool force: false}) async {
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

    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to clean."
    );
  }

  Future gc({
    bool aggressive: false,
    bool auto: false,
    bool force: false
  }) async {
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

    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to Garbage Collect."
    );
  }

  Future mv(String path, String destination) async {
    var args = ["mv", path, destination];
    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to move ${path} to ${destination}."
    );
  }

  Future<String> currentBranch() async {
    var result = await execute([
      "rev-parse",
      "--abbrev-ref",
      "HEAD"
    ]);
    return result.stdout.trim();
  }

  Future<String> parseRev(String input, {bool abbrevRef: false}) async {
    var args = ["rev-parse"];

    if (abbrevRef) {
      args.add("--abbrev-ref");
    }

    args.add(input);

    ProcessResult result = await execute(args);
    if (result.exitCode != 0) {
      throw new InvalidRevException(input);
    } else {
      return stripNewlines(result.stdout);
    }
  }

  Future fetch(String remote) async {
    var args = ["fetch", remote];
    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to fetch ${remote}."
    );
  }

  Future addRemote(String name, String url) async {
    var args = ["remote", "add", name, url];
    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to add remote '${name}' to '${url}'."
    );
  }

  Future removeRemote(String name) async {
    var args = ["remote", "remove", name];
    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to remove remote '${name}'."
    );
  }

  Future createBranch(String name, {String from}) async {
    var args = ["branch", name];
    if (from != null) {
      args.add(from);
    }

    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to create branch ${name}."
    );
  }

  Future fsck({bool full: false, bool strict: false}) async {
    var args = ["fsck"];

    if (full) {
      args.add("--full");
    }

    if (strict) {
      args.add("--strict");
    }

    var result = await execute(args);
    checkError(
      result.exitCode,
      "Failed to fsck."
    );
  }

  Future<List<GitRef>> listRemoteRefs({String url}) async {
    var args = ["ls-remote"];
    if (url != null) {
      args.add(url);
    }

    ProcessResult result = await execute(args);
    List<String> refLines = result.stdout.split("\n");
    var refs = [];
    for (var line in refLines) {
      if (line.trim().isEmpty) continue;

      var ref = new GitRef(this);

      var parts = line.split(_TAB_SPACE);
      parts.removeWhere((it) => it.trim().isEmpty);

      ref.commitSha = parts[0];
      ref.ref = parts[1];

      refs.add(ref);
    }

    return refs;
  }

  Future<List<String>> listBranches({String remote}) async {
    var refs = await listRefs();

    return refs.where((it) {
      bool valid = it.isCommit;
      if (remote != null) {
        valid = valid && it.remote == remote;
      }
      return valid;
    }).map((it) => it.name).toList();
  }

  Future<List<GitRef>> listRefs() async {
    var result = await execute(["for-each-ref"]);
    List<String> refLines = result.stdout.split("\n");
    var refs = [];
    for (var line in refLines) {
      if (line.trim().isEmpty) continue;

      var ref = new GitRef(this);

      var parts = line.split(_TAB_SPACE);

      ref.commitSha = parts[0];
      ref.type = parts[1];
      ref.ref = parts[2];

      refs.add(ref);
    }

    return refs;
  }

  Future createTag(String name, {String commit}) async {
    var args = ["tag", name];
    if (commit != null) {
      args.add(commit);
    }
    var code = await executeSimple(args);
    checkError(code, "Failed to create tag ${name}");
  }

  Future<List<String>> listTags() async {
    var refs = await listRefs();
    return refs
      .where((it) => it.isTag)
      .map((it) => it.name)
      .toSet()
      .toList();
  }

  Future deleteTag(String name) async {
    var code = await executeSimple(["tag", "-d", name]);
    checkError(code, "Failed to delete tag ${name}");
  }

  Future deleteBranch(String name) async {
    var code = await executeSimple(["branch", "-d", name]);
    checkError(code, "Failed to delete branch ${name}");
  }

  Future<int> executeSimple(List<String> args) async {
    var result = await executeCommand(
      "git",
      args: args,
      workingDirectory: directory.path,
      stdin: stdin
    );

    return result.exitCode;
  }

  Future<BetterProcessResult> execute(List<String> args, {
    bool binary: false,
    OutputHandler outputHandler,
    stdin,
    bool writeToBuffer: true
  }) async {
    var result = await executeCommand(
      "git",
      args: args,
      workingDirectory: directory.path,
      binary: binary,
      outputHandler: outputHandler,
      stdin: stdin,
      writeToBuffer: writeToBuffer
    );

    return result;
  }

  Future pushMirror(String url) async {
    var code = await executeSimple(["push", "--mirror", url]);
    checkError(code, "Failed to push mirror to ${url}");
  }

  Future init({bool bare: false}) async {
    var args = ["init"];

    if (bare) {
      args.add("--bare");
    }

    var code = await executeSimple(args);
    checkError(code, "Failed to init repository.");
  }

  Future<GitCommit> getCommit(String commitSha) async {
    var commits = await listCommits(limit: 1, range: commitSha);
    if (commits.length != 1) {
      throw new GitException("Unknown Commit: ${commitSha}");
    }
    return commits.first;
  }

  checkError(int code, String message) {
    if (code != GitExitCodes.OK) {
      throw new GitException(message);
    }
  }

  static handleProcess(handler, {bool inherit: false}) {
    var adapter = new ProcessAdapterReferences();
    adapter.flags.inherit = inherit;
    return runZoned(() {
      if (handler is ProcessAdapterHandler) {
        return handler(adapter);
      } else {
        return handler();
      }
    }, zoneValues: {
      "legit.io.process.ref": adapter
    });
  }
}
