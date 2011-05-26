module dpk.build;

import std.algorithm, std.array, std.conv, std.exception, std.functional, std.path, std.stdio, std.string, std.range;
import dpk.ctx, dpk.config, dpk.pkgdesc, dpk.install, dpk.util, dpk.utrunner;
version (Posix) import core.sys.posix.sys.stat, std.string : toStringz;


int runBuild(Ctx ctx) {
  PkgDesc local;
  if (collectException(ctx.pkgdesc, local)) {
    stderr.writeln("failed to load dpk.cfg");
    return 1;
  }
  foreach(lib; local.sectsByType!("lib")()) {
    buildLib(ctx, lib, depFlags(ctx, lib));
  }
  foreach(bin; local.sectsByType!("bin")()) {
    buildBin(ctx, bin, depFlags(ctx, bin));
  }
  return 0;
}

int runDocs(Ctx ctx) {
  foreach(tgt; ctx.pkgdesc.sections) {
    if (to!bool(tgt.get("docs")))
      buildDocs(ctx, tgt);
  }
  return 0;
}

int runImports(Ctx ctx) {
  foreach(tgt; ctx.pkgdesc.sections) {
    if (to!bool(tgt.get("imports")))
      buildImports(ctx, tgt);
  }
  return 0;
}

int runClean(Ctx ctx) {
  foreach(dir; ["bin32", "bin64", "lib32", "lib64", ".unittest32", ".unittest64"]) {
    if (std.file.exists(dir) && std.file.isDir(dir)) {
      writeln("clean:\t", dir);
      std.file.rmdirRecurse(dir);
    }
  }
  return 0;
}

int runDistClean(Ctx ctx) {
  foreach(dir; ["bin32", "bin64", "lib32", "lib64", ".unittest32", ".unittest64", "doc", "import"]) {
    if (std.file.exists(dir) && std.file.isDir(dir)) {
      writeln("clean:\t", dir);
      std.file.rmdirRecurse(dir);
    }
  }
  return 0;
}

int runList(Ctx ctx) {
  foreach(pkg; ctx.installedPkgs) {
    writeln("\t", getName(pkg));
  }
  return 0;
}

int runInstall(Ctx ctx) {
  runDistClean(ctx);
  runBuild(ctx);
  runImports(ctx);
  runDocs(ctx);
  string[] files;
  scope(failure) foreach(file; files) { removeFile(file); }

  foreach(bin; ctx.pkgdesc.sectsByType!("bin")()) {
    if (to!bool(bin.get("install")))
      files ~= installBin(ctx, bin);
  }
  foreach(lib; ctx.pkgdesc.sectsByType!("lib")()) {
    if (to!bool(lib.get("install")))
      files ~= installLib(ctx, lib);
  }
  files ~= installFolder(ctx, "doc");
  files ~= installFolder(ctx, "import");
  ctx.installedFiles = files;
  installPkgDesc(ctx);
  return 0;
}

int runUninstall(Ctx ctx) {
  void uninstall(string hint) {
    if (auto pkg = findPkgByName(ctx, hint)) {
      writeln("uninstall:\t", getName(pkg));
      uninstallPkg(ctx, pkg);
    }
  }

  auto args = filter!(q{!a.startsWith("-")})(ctx.args);
  if (args.empty) {
    string name;
    if (collectException(ctx.pkgdesc.name, name)) {
      stderr.writeln("usage dpk uninstall [pkg-name]");
      return 1;
    }
    uninstall(name);
  } else {
    foreach(arg; args) {
      uninstall(arg);
    }
  }
  return 0;
}

int runTest(Ctx ctx) {
  PkgDesc local;
  if (collectException(ctx.pkgdesc, local)) {
    stderr.writeln("failed to load dpk.cfg");
    return 1;
  }
  string[] tests;
  foreach(lib; local.sectsByType!("lib")()) {
    tests ~= buildLibUt(ctx, lib, depFlags(ctx, lib));
  }
  foreach(bin; local.sectsByType!("bin")()) {
    tests ~= buildBinUt(ctx, bin, depFlags(ctx, bin));
  }
  foreach(test; tests) {
    if (ctx.verbose) writeln(test);
    //    druntime currently quits with an EXIT_FAILURE if excecution is stopped
    //    enforce(!std.process.system(test));
    std.process.system(test);
  }
  return 0;
}

private:

void buildLib(Ctx ctx, Section lib, string link) {
  auto root = lib.get("root");
  auto srcs = resolveGlobs(lib.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto tgtpath = rel2abs(std.path.join(libDir(ctx), libName(ctx, lib)));
  writeln("lib:\t", tgtpath);
  auto cmd = fmtString("dmd -lib %s -of%s %s %s",
    join(ctx.args, " "), tgtpath, join(srcs, " "), link);
  if (ctx.verbose) writeln(cmd);
  execCmdInDir(cmd, root);
}

string buildLibUt(Ctx ctx, Section lib, string link) {
  auto root = lib.get("root");
  auto srcs = resolveGlobs(lib.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));
  srcs ~= rel2abs(createEmptyMainSrc(utDir(ctx)));
  srcs ~= rel2abs(createUtRunnerSrc(utDir(ctx)));

  auto tgtpath = rel2abs(std.path.join(utDir(ctx), binName(ctx, lib)));
  writeln("utlib:\t", tgtpath);
  auto cmd = fmtString("dmd %s -of%s %s %s",
    join(uniq(ctx.args ~ "-unittest"), " "), tgtpath, join(srcs, " "), link);
  if (ctx.verbose) writeln(cmd);
  execCmdInDir(cmd, root);
  return tgtpath;
}

void buildBin(Ctx ctx, Section bin, string link) {
  auto root = bin.get("root");
  auto srcs = resolveGlobs(bin.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto tgtpath = rel2abs(std.path.join(binDir(ctx), binName(ctx, bin)));
  writeln("bin:\t", tgtpath);
  auto cmd = fmtString("dmd %s -of%s %s %s",
    join(ctx.args, " "), tgtpath, join(srcs, " "), link);
  if (ctx.verbose) writeln(cmd);
  execCmdInDir(cmd, root);
}

string buildBinUt(Ctx ctx, Section bin, string link) {
  auto root = bin.get("root");
  auto srcs = resolveGlobs(bin.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));
  srcs ~= rel2abs(createUtRunnerSrc(utDir(ctx)));

  auto tgtpath = rel2abs(std.path.join(utDir(ctx), binName(ctx, bin)));
  writeln("utbin:\t", tgtpath);
  auto cmd = fmtString("dmd %s -of%s %s %s",
    join(uniq(ctx.args ~ "-unittest"), " "), tgtpath, join(srcs, " "), link);
  if (ctx.verbose) writeln(cmd);
  execCmdInDir(cmd, root);
  return tgtpath;
}

void buildImports(Ctx ctx, Section tgt) {
  auto root = tgt.get("root");
  auto srcs = resolveGlobs(tgt.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto imppath = rel2abs("import");
  writeln("imports:\t", imppath);
  auto cmd = fmtString("dmd -c -o- -op -Hd%s %s", imppath, join(srcs, " "));
  if (ctx.verbose) writeln(cmd);
  execCmdInDir(cmd, root);
}

void buildDocs(Ctx ctx, Section tgt) {
  auto root = tgt.get("root");
  auto srcs = resolveGlobs(tgt.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto docpath = rel2abs("doc");
  writeln("docs:\t", docpath);
  auto cmd = fmtString("dmd -c -o- -op -Dd%s %s", docpath, join(srcs, " "));
  if (ctx.verbose) writeln(cmd);
  execCmdInDir(cmd, root);
}

string depFlags(Ctx ctx, Section target) {
  auto deps = target.get("depends");
  string flags;

  string pkgLinkFlags(PkgDesc pkgdesc) {
    string result;
    auto libs = pkgdesc.sectsByType!("lib")();
    foreach(lib; libs) {
      result ~= fmtString("-L-l%s ", tgtName(ctx, lib));
      result ~= depFlags(ctx, lib);
    }
    auto hdrs = pkgdesc.sectsByType!("headers")();
    foreach(hdr; hdrs) {
      result ~= depFlags(ctx, hdr);
    }
    return result;
  }

  if (!deps.empty) {
    flags = fmtString("-L-L%s ", installPath(ctx, libDir(ctx)));
    foreach(dep; splitter(deps)) {
      if (tolower(dep) == ctx.pkgdesc.name) {
        auto hdrs = ctx.pkgdesc.sectsByType!("headers")();
        auto libs = ctx.pkgdesc.sectsByType!("lib")();
        foreach(lib; chain(hdrs, libs))
          flags ~= fmtString("-I%s ", rel2abs(lib.get("root")));
        flags ~= fmtString("-L-L%s ", rel2abs(libDir(ctx)));
        flags ~= pkgLinkFlags(ctx.pkgdesc);
      } else if (auto cfgname = findPkgByName(ctx, dep)) {
        flags ~= pkgLinkFlags(loadPkgDesc(ctx, cfgname));
      } else {
        throw new Exception(fmtString("Missing pkg dependecy %s", dep));
      }
    }
  }

  foreach(clib; splitter(target.get("links"))) {
    flags ~= fmtString("-L-l%s ", clib);
  }
  return flags;
}

string[] installBin(Ctx ctx, Section bin) {
  auto instpath = installPath(ctx, binDir(ctx));
  auto binname = binName(ctx, bin);
  auto files = copyRel(instpath, binname, binDir(ctx));
  version (Posix)
    core.sys.posix.sys.stat.chmod(toStringz(join(instpath, binname)), octal!755);
  return files;
}

string[] installLib(Ctx ctx, Section lib) {
  return copyRel(installPath(ctx, libDir(ctx)), libName(ctx, lib), libDir(ctx));
}

string[] installFolder(Ctx ctx, string dir) {
  if (std.file.exists(dir) && std.file.isDir(dir))
    return copyRel(installPath(ctx, dir), "**", dir);
  else
    return null;
}

void uninstallPkg(Ctx ctx, string pkgname) {
  auto pkgdesc = loadPkgDesc(ctx, pkgname);

  foreach(file; splitter(pkgdesc.get("install").get("files"))) {
    removeFile(installPath(ctx, file));
  }
  uninstallPkgDesc(ctx, pkgname);
}

version (Posix) {
  enum libpre = "lib";
  enum libsuf = ".a";
  enum binpre = "";
  enum binsuf = "";
} else version (Windows) {
  enum libpre = "";
  enum libsuf = ".lib";
  enum binpre = "";
  enum binsuf = ".exe";
}

string libDir(Ctx ctx) {
  return "lib" ~ to!string(ctx.dflags.wordsize);
}

string binDir(Ctx ctx) {
  return "bin" ~ to!string(ctx.dflags.wordsize);
}

string utDir(Ctx ctx) {
  return ".unittest" ~ to!string(ctx.dflags.wordsize);
}

string libName(Ctx ctx, Section lib) {
  return libpre ~ tgtName(ctx, lib) ~ libsuf;
}

string binName(Ctx ctx, Section bin) {
  return binpre ~ tgtName(ctx, bin) ~ binsuf;
}

string tgtName(Ctx ctx, Section tgt) {
  auto name = tgt.get("target", new Exception("Missing target property."));
  assert(!name.empty);
  return name ~ ctx.dflags.suffix;
}
