module dpk.main;

import std.array, std.stdio, std.string;
import dpk.build, dpk.ctx;

enum usage = "usage dmd-pkg [build | clean | distclean | docs | imports |\n"
  "\tinstall | list | uninstall | test ] compilerflags";
enum Mode { build, clean, distclean, docs, imports, install, list, uninstall, test };

Mode getMode(ref string[] args) {
  if (args.empty)
    return Mode.build;

  auto mode = toLower(args.front);
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
    return runClean(ctx);
  case Mode.distclean:
    return runDistClean(ctx);
  case Mode.docs:
    return runDocs(ctx);
  case Mode.imports:
    return runImports(ctx);
  case Mode.install:
    return runInstall(ctx);
  case Mode.list:
    return runList(ctx);
  case Mode.uninstall:
    return runUninstall(ctx);
  case Mode.test:
    return runTest(ctx);
  }
}
