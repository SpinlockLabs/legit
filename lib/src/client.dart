part of legit;

class GitClient {
  static final RegExp _WHITESPACE = new RegExp(r"\s");

  static String _version;
  static Future<String> version() async {
    if (_version == null) {
      try {
	      BetterProcessResult rslt = await executeCommand('git', args:['--version'], writeToBuffer:true);
	      if (rslt.exitCode == 0 && rslt.output.startsWith('git version ')) {
	        _version = rslt.output.substring(12).trim();
	      } else {
	        _version = '';
	      }
      } catch (err) {
         _version = '';
      }
    }
    return _version;
  }

  static Future<bool> supported() async {
    return (await version()) != '';
  }

  final Directory directory;

  factory GitClient.forPath(String path) {
    var dir = new Directory(path);
    return new GitClient.forDirectory(dir);
  }

  factory GitClient.forCurrentDirectory() {
    return new GitClient.forDirectory(Directory.current);
  }

  factory GitClient.forDirectory(Directory dir) {
    return new GitClient._(dir.absolute);
  }

  GitClient._(this.directory);

  static GitClient open(String path) {
    return new GitClient.forPath(path);
  }

  static Future<GitClient> openOrCloneRepository(String url, String path, {
    bool bare: false,
    bool mirror: false
  }) async {
    var client = new GitClient.forPath(path);
    if (await client.directory.exists() && await client.isRepository()) {
      return client;
    } else {
      return await cloneRepositoryTo(url, path, bare: bare, mirror: mirror);
    }
  }

  Directory getRealDirectory(String path) {
    return new Directory(pathlib.join(directory.path, path));
  }

  File getRealFile(String path) {
    return new File(pathlib.join(directory.path, path));
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

    if (!(await client.directory.exists())) {
      await client.directory.create(recursive: true);
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
    })).where((it) => it.isNotEmpty).map((it) {
      return new GitTreeFile(it[2], it[3]);
    }).toList();
  }

  Future<List<int>> getBinaryBlob(String blob) async {
    var args = ["cat-file", "blob", blob];
    var result = await execute(args, binary: true);
    if (result.exitCode != 0) {
      throw new GitException("Blob not Found");
    }

    return result.stdout;
  }

  Future<String> getTextBlob(String blob) async {
    var binary = await getBinaryBlob(blob);
    return const Utf8Decoder(allowMalformed: true).convert(binary);
  }

  Future<GitCommit> commit(String message) async {
    var args = ["commit", "-m", message];

    var result = await execute(args);
    if (result.exitCode != 0) {
      return null;
    } else {
      var commits = await listCommits(limit: 1);
      if (commits == null) {
        return null;
      } else {
        return commits[0];
      }
    }
  }

  Future<List<GitCommit>> listCommits({int limit, String range, String file, bool detail: false}) async {
    var args = [
      "log",
      "--format=format:-;;;;-%H%n%T%n%aN%n%aE%n%cN%n%cE%n%ai%n%ci%n%d%n%B-;;;-",
      "--no-color",
      "--decorate"
    ];

    if (limit != null) {
      args.add("--max-count=${limit}");
    }

    if (range != null) {
      args.add(range);
    }
    if (detail) {
      args.add('--name-status');
    }

    if (file != null) {
      args.addAll(["--", file]);
    }

    BetterProcessResult result = await execute(args);

    if (result.exitCode != 0) {
      return null;
    } else {
      String output = result.stdout.toString();
      var commits = <GitCommit>[];
      List<String> clines = output.split("-;;;;-")
        .map((it) => it.trim())
        .toList();
      clines.removeWhere((it) => it.isEmpty || !it.contains("\n"));

      for (String line in clines) {
        List<GitCommitChange> changes;
        List<String> linechange = line.split('-;;;-');
        line = linechange[0];

        if (detail) {
          changes = <GitCommitChange>[];
          String changeStr = linechange[1];
          List changesRaw = changeStr.split('\n');
          for (String change in changesRaw) {
            List changeSplit = change.split('\t');
            if (changeSplit.length == 2) {
              changes.add(new GitCommitChange(changeSplit[1], changeSplit[0]));
            }
          }
        }

        var parts = line.split("\n");
        var commit = new GitCommit(this);
        commit.changes = changes;
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
        commit.setDecorate(parts[8]);
        commit.message = parts.getRange(9, parts.length).join("\n").trim();
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

  Future push({String remote: "origin", String branch, bool all: false, bool mirror: false}) async {
    var args = ["push"];
    if (remote != null) {
      args.add(remote);
    }

    if (branch != null) {
      args.add(branch);
    }

    if (all && branch == null) {
      args.add("--all");
    }

    if (mirror) {
      args.add("--mirror");
    }

    args.add("--porcelain");

    var result = await execute(args);
    checkError(result.exitCode, "Failed to push ${branch} to ${remote}");
  }

  Future pull({String origin, String branch, bool all: true}) async {
    var args = ["pull"];
    if (all) {
      args.add("--all");
    }

    if (origin != null) {
      args.add(origin);
    }

    if (branch != null) {
      args.add(branch);
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
      "Failed to remove ${path}."
    );
  }

  Future<bool> hasRemote(String remote) async {
    var result = await execute(["remote"]);
    return result.stdout.toString().split(_WHITESPACE).contains(remote);
  }

  Future<bool> isRepository() async {
    var result = await execute(["rev-parse"]);
    return result.exitCode == GitExitCodes.OK;
  }

  Future<bool> isRepositoryRoot() async {
    var result = await execute(["rev-parse", "--show-cdup"]);
    return result.exitCode == GitExitCodes.OK && result.output.trim() == "";
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

  Future<Uint8List> createArchive(String ref, String format, {
    String prefix
  }) async {
    var args = ["archive"];
    if (prefix != null) {
      args.addAll(["--prefix", prefix]);
    }
    args.addAll(["--format", format]);
    args.add(ref);
    var result = await execute(args, binary: true);
    checkError(result.exitCode, "Failed to create archive.");
    return new Uint8List.fromList(result.stdout);
  }

  Future unpackObjects(pack) async {
    Uint8List data;

    if (pack is Uint8List) {
      data = pack;
    } else if (pack is List) {
      data = new Uint8List.fromList(pack);
    } else if (pack is File) {
      data = await pack.readAsBytes();
    } else if (pack is String) {
      data = await new File(pack).readAsBytes();
    } else {
      throw new GitException("Bad Pack: ${pack}");
    }

    var result = await execute([
      "unpack-objects",
    ], stdin: data);

    checkError(result.exitCode, "Failed to unpack objects.");
  }

  Future<List<String>> listObjects() async {
    var result = await execute([
      "rev-list",
      "--objects",
      "--all"
    ]);

    checkError(result.exitCode, "Failed to list objects.");
    return result.stdout.toString().split("\n").map((String m) {
      return m.trim();
    }).map((String m) {
      var idx = m.indexOf(" ");
      if (idx == -1) {
        idx = m.length;
      }
      return m.substring(0, idx);
    }).where((String m) {
      return m.isNotEmpty;
    }).toList();
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

  Future fetch({String remote, bool all: true}) async {
    var args = ["fetch"];

    if (remote != null) {
      args.add(remote);
    }

    if (all && remote == null) {
      args.add("--all");
    }

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

      var parts = line.split(_WHITESPACE);
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
    var refs = <GitRef>[];
    for (var line in refLines) {
      if (line.trim().isEmpty) continue;

      var ref = new GitRef(this);

      var parts = line.split(_WHITESPACE);

      ref.commitSha = parts[0];
      ref.type = parts[1];
      ref.ref = parts[2];

      refs.add(ref);
    }

    return refs;
  }

  Future createTag(String name, {String commit, String message}) async {
    var args = ["tag", name];
    if (commit != null) {
      args.add(commit);
    }
    if (message != null) {
      args.add('-m');
      args.add(message);
    }
    var result = await execute(args);
    checkError(result.exitCode, "Failed to create tag ${name}");
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
    var result = await execute(["tag", "-d", name]);
    checkError(result.exitCode, "Failed to delete tag ${name}");
  }

  Future deleteBranch(String name, {bool force: false}) async {
    var result = await execute([
      "branch",
      force ? "-D" : "-d",
      name
    ]);
    checkError(result.exitCode, "Failed to delete branch ${name}");
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
    var args = ["push", "--mirror", url];
    var result = await execute(args);
    checkError(result.exitCode, "Failed to push mirror to ${url}");
  }

  Future init({bool bare: false}) async {
    var args = ["init"];

    if (bare) {
      args.add("--bare");
    }

    var result = await execute(args);
    checkError(result.exitCode, "Failed to init repository.");
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

  Future delete() async {
    await directory.delete(recursive: true);
  }

  Future<GitClient> createWorktree(String path, {
    String source,
    String branch,
    bool force: true,
    bool detach: false
  }) async {
    path = pathlib.join(directory.path, path);

    var args = ["worktree", "add"];

    if (force) {
      args.add("--force");
    }

    if (detach) {
      args.add("--detatch");
    }

    if (branch != null) {
      args.addAll(["-b", branch]);
    }

    args.add(path);
    if (source != null) {
      args.add(source);
    }

    var result = await execute(args);
    checkError(result.exitCode, "Failed to create worktree at ${path}");
    return new GitClient.forPath(path);
  }

  Future pruneWorktrees() async {
    var args = ["worktree", "prune"];
    var result = await execute(args);
    checkError(result.exitCode, "Failed to prune worktrees.");
  }

  static handleConfigure(handler, {
    bool inherit: false,
    File logFile,
    LogHandler logHandler
  }) {
    var adapter = new ProcessAdapterReferences();
    adapter.flags.inherit = inherit;
    adapter.flags.logFile = logFile;
    adapter.flags.logHandler = logHandler;
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
