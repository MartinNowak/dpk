module dpk.main;

import std.algorithm, std.array, std.stdio, std.string;
import dpk.build, dpk.ctx;

string usage() {
  return "dpk [command]

commands:
  build      build all targets (default command)
  clean      clean binary output dirs
  distclean  clean all output dirs
  docs       build documentation
  imports    build imports
  install    install a package
  list       list installed packages
  uninstall  uninstall a package
  test       run unit tests

See 'dpk help <command>' for help on a specific command.
";
}

string usage(Mode mode) {
  final switch (mode) {
  case Mode.build:
    return "dpk [build] <DFLAGS>
builds all targets from the local dpk.cfg file";
  case Mode.clean:
    return "dpk clean
removes all binary and lib output folders";
  case Mode.distclean:
    return "dpk distclean
removes all output folders";
  case Mode.docs:
    return "dpk docs
builds doc files for all targets";
  case Mode.imports:
    return "dpk docs
builds imports files for all targets";
  case Mode.install:
    return "dpk install <DFLAGS>
builds and installs all targets from the local dpk.cfg";
  case Mode.list:
    return "dpk list
lists all installed packages";
  case Mode.uninstall:
    return "dpk uninstall [name]
uninstalls the local package or the one matched by name";
  case Mode.test:
    return "dpk test <DFLAGS>
builds unittest binaries for all bin/lib targets and runs them";
  }
}

enum Mode { build, clean, distclean, docs, imports, install, list, uninstall, test };

bool getHelp(ref string[] args) {
  if (args.empty || ["--help", "help", "-h"].countUntil(args.front) == -1)
    return false;
  args.popFront;
  return true;
}

bool getMode(ref string[] args, out Mode mode) {
  if (args.empty)
    return Mode.build;

  auto arg1 = toLower(args.front);
  foreach(i, name; __traits(allMembers, Mode)) {
    if (name == arg1) {
      args.popFront;
      mode = cast(Mode)i;
      return true;
    }
  }
  return false;
}

int main(string[] args) {
  args.popFront;

  Mode mode;

  if (getHelp(args)) {
    if (getMode(args, mode))
      writeln(usage(mode));
    else
      writeln(usage());
    return 0;
  }

  if (getMode(args, mode)) {
    // check for 'dpk mode --help'
    if (getHelp(args)) {
      writeln(usage(mode));
      return 0;
    }
  } else {
    mode = Mode.build;
  }


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
