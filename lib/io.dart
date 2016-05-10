library legit.io;

import "dart:async";
import "dart:convert";
import "dart:io";

import "id.dart";

typedef ProcessResultHandler(BetterProcessResult result);
typedef ProcessHandler(Process process);
typedef OutputHandler(String string);
typedef ProcessAdapterHandler(ProcessAdapterReferences adapter);
typedef LogHandler(String message);

Stdin get _stdin => stdin;

class BetterProcessResult extends ProcessResult {
  final String output;

  BetterProcessResult(int pid, int exitCode, stdout, stderr, this.output)
    : super(pid, exitCode, stdout, stderr);
}

class ProcessAdapterFlags {
  bool inherit = false;
  File logFile;
  LogHandler logHandler;
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
    bool inheritStdin: false,
    LogHandler logHandler
  }) async {
  ProcessAdapterReferences refs = Zone.current["legit.io.process.ref"];

  if (refs != null) {
    outputFile = outputFile != null ? outputFile : refs.flags.logFile;
    logHandler = logHandler != null ? logHandler : refs.flags.logHandler;
  }

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

    var id = process.pid.toString();

    if (refs != null) {
      refs.pushProcess(process);
      inherit = inherit || refs.flags.inherit;
    }

    if (raf != null) {
      await raf.writeln(
        "[${currentTimestamp}][${id}] == Executing ${executable}"
          " with arguments ${args} (pid: ${process.pid}) =="
      );
    }

    if (logHandler != null) {
      logHandler(
        "[${currentTimestamp}][${id}] == Executing ${executable}"
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
      process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((str) async {
        if (writeToBuffer) {
          ob.writeln(str);
          buff.writeln(str);
        }

        if (stdoutHandler != null) {
          stdoutHandler(str);
        }

        if (outputHandler != null) {
          outputHandler(str);
        }

        if (inherit) {
          stdout.writeln(str);
        }

        if (raf != null) {
          await raf.writeln("[${currentTimestamp}][${id}] ${str}");
        }

        if (logHandler != null) {
          logHandler("[${currentTimestamp}][${id}] ${str}");
        }
      });

      process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((str) async {
        if (writeToBuffer) {
          eb.writeln(str);
          buff.writeln(str);
        }

        if (stderrHandler != null) {
          stderrHandler(str);
        }

        if (outputHandler != null) {
          outputHandler(str);
        }

        if (inherit) {
          stderr.writeln(str);
        }

        if (raf != null) {
          await raf.writeln("[${currentTimestamp}][${id}] ${str}");
        }

        if (logHandler != null) {
          logHandler("[${currentTimestamp}][${id}] ${str}");
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
    await new Future.delayed(const Duration(milliseconds: 1));
    var pid = process.pid;

    if (raf != null) {
      await raf.writeln(
        "[${currentTimestamp}][${id}] == Exited with status ${code} =="
      );
      await raf.flush();
      await raf.close();
    }

    if (logHandler != null) {
      logHandler("[${currentTimestamp}][${id}] == Exited with status ${code} ==");
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
