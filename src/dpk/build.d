module dpk.build;

import std.array, std.conv, std.exception, std.functional, std.path, std.stdio;
import dpk.ctx, dpk.config, dpk.pkgdesc, dpk.install, dpk.util;
version (Posix) import core.sys.posix.sys.stat, std.string : toStringz;


int runBuild(Ctx ctx) {
  foreach(lib; ctx.pkgdesc.sectsByType!("lib")()) {
    buildLib(ctx, lib, depFlags(ctx, lib));
  }
  foreach(bin; ctx.pkgdesc.sectsByType!("bin")()) {
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
  foreach(dir; ["bin32", "bin64", "lib32", "lib64"]) {
    if (std.file.exists(dir) && std.file.isDir(dir)) {
      writeln("clean:\t", dir);
      std.file.rmdirRecurse(dir);
    }
  }
  return 0;
}

int runDistClean(Ctx ctx) {
  foreach(dir; ["bin32", "bin64", "lib32", "lib64", "doc", "import"]) {
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

private:

void buildLib(Ctx ctx, Section lib, string link) {
  auto root = lib.get("root");
  auto srcs = resolveGlobs(lib.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto tgtpath = rel2abs(std.path.join(libDir(ctx), libpre ~ tgtName(ctx, lib) ~ libsuf));
  writeln("lib:\t", tgtpath);
  auto cmd = fmtString("dmd -lib %s -of%s %s %s",
    join(ctx.args, " "), tgtpath, join(srcs, " "), link);
  execCmdInDir(cmd, root);
}

void buildBin(Ctx ctx, Section bin, string link) {
  auto root = bin.get("root");
  auto srcs = resolveGlobs(bin.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto tgtpath = rel2abs(std.path.join(binDir(ctx), binName(ctx, bin)));
  writeln("bin:\t", tgtpath);
  auto cmd = fmtString("dmd %s -of%s %s %s",
    join(ctx.args, " "), tgtpath, join(srcs, " "), link);
  execCmdInDir(cmd, root);
}

void buildImports(Ctx ctx, Section tgt) {
  auto root = tgt.get("root");
  auto srcs = resolveGlobs(tgt.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto imppath = rel2abs("import");
  writeln("imports:\t", imppath);
  auto cmd = fmtString("dmd -c -o- -op -Hd%s %s", imppath, join(srcs, " "));
  execCmdInDir(cmd, root);
}

void buildDocs(Ctx ctx, Section tgt) {
  auto root = tgt.get("root");
  auto srcs = resolveGlobs(tgt.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto docpath = rel2abs("doc");
  writeln("docs:\t", docpath);
  auto cmd = fmtString("dmd -c -o- -op -Dd%s %s", docpath, join(srcs, " "));
  execCmdInDir(cmd, root);
}

string depFlags(Ctx ctx, Section target) {
  auto deps = split(target.get("depends"));
  string links = fmtString("-L-L%s ", installPath(ctx, libDir(ctx)));

  if (deps.length) {
    foreach(dep; deps) {
      if (auto cfgname = findPkgByName(ctx, dep)) {
        auto pkgdesc = loadPkgDesc(ctx, cfgname);
        foreach(lib; pkgdesc.sectsByType!("lib")())
          links ~= fmtString("-L-l%s ", tgtName(ctx, lib));
      } else
        throw new Exception(fmtString("Missing pkg dependecy %s", dep));
    }
  }
  return links;
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

string libName(Ctx ctx, Section lib) {
  return libpre ~ tgtName(ctx, lib) ~ libsuf;
}

string binName(Ctx ctx, Section bin) {
  return binpre ~ tgtName(ctx, bin) ~ binsuf;
}

string tgtName(Ctx ctx, Section tgt) {
  return tgt.get("target") ~ ctx.dflags.suffix;
}
