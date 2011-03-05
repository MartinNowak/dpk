module dpk.main;

import std.array, std.stdio, std.string;
import dpk.build, dpk.ctx;

enum usage = "usage dmd-pkg [build | clean | distclean | docs | imports |\n"
  "\tinstall | list | uninstall] compilerflags";
enum Mode { build, clean, distclean, docs, imports, install, list, uninstall };

Mode getMode(ref string[] args) {
  if (args.empty)
    return Mode.build;

  auto mode = tolower(args.front);
  foreach(i, name; __traits(allMembers, Mode)) {
    if (name == mode) {
      args.popFront;
      return cast(Mode)i;
    }
  }
  return Mode.build;
}

int main(string[] args) {
  args.popFront;

  if (!args.empty && args.front == "--help") {
    writeln(usage);
    return 0;
  }

  Mode mode = getMode(args);
  scope auto ctx = new Ctx(args);

  final switch (mode) {
  case Mode.build:
    return runBuild(ctx);
  case Mode.clean:
    return runClean(args);
  case Mode.distclean:
    return runDistClean(args);
  case Mode.docs:
    return runDocs(ctx);
  case Mode.imports:
    return runImports(ctx);
  case Mode.install:
    return runInstall(args);
  case Mode.list:
    return runList(args);
  case Mode.uninstall:
    return runUninstall(args);
  }
}

int runClean(string[]) { assert(0); }
int runDistClean(string[]) { assert(0); }
int runInstall(string[]) { assert(0); }
int runList(string[]) { assert(0); }
int runUninstall(string[]) { assert(0); }
