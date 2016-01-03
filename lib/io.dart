library legit.io;

import "dart:async";
import "dart:convert";
import "dart:io";

typedef ProcessResultHandler(BetterProcessResult result);
typedef ProcessHandler(Process process);
typedef OutputHandler(String string);
typedef ProcessAdapterHandler(ProcessAdapterReferences adapter);

Stdin get _stdin => stdin;

class BetterProcessResult extends ProcessResult {
  final String output;

  BetterProcessResult(int pid, int exitCode, stdout, stderr, this.output)
    : super(pid, exitCode, stdout, stderr);
}

class ProcessAdapterFlags {
  bool inherit = false;
}

class ProcessAdapterReferences {
  BetterProcessResult result;
  Process process;
  ProcessAdapterFlags flags = new ProcessAdapterFlags();

  Future<BetterProcessResult> get onResultReady {
    if (result != null) {
      return new Future.value(result);
    } else {
      var c = new Completer<BetterProcessResult>();
      _onResultReady.add(c.complete);
      return c.future;
    }
  }

  Future<Process> get onProcessReady {
    if (process != null) {
      return new Future.value(process);
    } else {
      var c = new Completer<Process>();
      _onProcessReady.add(c.complete);
      return c.future;
    }
  }

  List<ProcessResultHandler> _onResultReady = [];
  List<ProcessHandler> _onProcessReady = [];

  void pushProcess(Process process) {
    this.process = process;
    while (_onProcessReady.isNotEmpty) {
      _onProcessReady.removeAt(0)(result);
    }
  }

  void pushResult(BetterProcessResult result) {
    this.result = result;
    while (_onResultReady.isNotEmpty) {
      _onResultReady.removeAt(0)(result);
    }
  }
}

Future<BetterProcessResult> executeCommand(String executable,
  {
    List<String> args: const [],
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    stdin,
    ProcessHandler handler,
    OutputHandler stdoutHandler,
    OutputHandler stderrHandler,
    OutputHandler outputHandler,
    File outputFile,
    bool inherit: false,
    bool writeToBuffer: false,
    bool binary: false,
    ProcessResultHandler resultHandler,
    bool inheritStdin: false
  }) async {
  ProcessAdapterReferences refs = Zone.current["legit.io.process.ref"];

  IOSink raf;

  if (outputFile != null) {
    if (!(await outputFile.exists())) {
      await outputFile.create(recursive: true);
    }

    raf = await outputFile.openWrite(mode: FileMode.APPEND);
  }

  try {
    Process process = await Process.start(executable, args,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell
    );

    if (refs != null) {
      refs.pushProcess(process);
      inherit = inherit || refs.flags.inherit;
    }

    if (raf != null) {
      await raf.writeln(
        "[${currentTimestamp}] == Executing ${executable}"
          " with arguments ${args} (pid: ${process.pid}) =="
      );
    }

    var buff = new StringBuffer();
    var ob = new StringBuffer();
    var eb = new StringBuffer();

    var obytes = <int>[];
    var ebytes = <int>[];
    var sbytes = <int>[];

    if (!binary) {
      process.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((str) async {
        if (writeToBuffer) {
          ob.write(str);
          buff.write(str);
        }

        if (stdoutHandler != null) {
          stdoutHandler(str);
        }

        if (outputHandler != null) {
          outputHandler(str);
        }

        if (inherit) {
          stdout.write(str);
        }

        if (raf != null) {
          await raf.writeln("[${currentTimestamp}] ${str}");
        }
      });

      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((str) async {
        if (writeToBuffer) {
          eb.write(str);
          buff.write(str);
        }

        if (stderrHandler != null) {
          stderrHandler(str);
        }

        if (outputHandler != null) {
          outputHandler(str);
        }

        if (inherit) {
          stderr.write(str);
        }

        if (raf != null) {
          await raf.writeln("[${currentTimestamp}] ${str}");
        }
      });
    } else {
      process.stdout.listen((bytes) {
        obytes.addAll(bytes);
        sbytes.addAll(bytes);
      });

      process.stderr.listen((bytes) {
        obytes.addAll(bytes);
        ebytes.addAll(bytes);
      });
    }

    if (handler != null) {
      handler(process);
    }

    if (stdin != null) {
      if (stdin is Stream) {
        stdin.listen(process.stdin.add, onDone: process.stdin.close);
      } else if (stdin is List) {
        process.stdin.add(stdin);
      } else {
        process.stdin.write(stdin);
        await process.stdin.close();
      }
    } else if (inheritStdin) {
      _stdin.listen(process.stdin.add, onDone: process.stdin.close);
    }

    var code = await process.exitCode;
    var pid = process.pid;

    if (raf != null) {
      await raf.writeln(
        "[${currentTimestamp}] == Exited with status ${code} =="
      );
      await raf.flush();
      await raf.close();
    }

    var result = new BetterProcessResult(
      pid,
      code,
      binary ? sbytes : ob.toString(),
      binary ? ebytes : eb.toString(),
      binary ? obytes : buff.toString()
    );

    if (resultHandler != null) {
      resultHandler(result);
    }

    if (refs != null) {
      refs.pushResult(result);
    }

    return result;
  } finally {
    if (raf != null) {
      await raf.flush();
      await raf.close();
    }
  }
}

String get currentTimestamp {
  return new DateTime.now().toString();
}
