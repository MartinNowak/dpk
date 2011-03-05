module dpk.build;

import std.array, std.conv, std.exception, std.functional, std.path, std.stdio;
import dpk.ctx, dpk.config, dpk.pkgdesc, dpk.install, dpk.util;

int runBuild(Ctx ctx) {
  auto pkgDesc = loadLocalPkgDesc();
  foreach(lib; pkgDesc.sectsByType!("lib")()) {
    buildLib(ctx, lib, depFlags(ctx, lib));
  }
  foreach(bin; pkgDesc.sectsByType!("bin")()) {
    buildBin(ctx, bin, depFlags(ctx, bin));
  }
  return 0;
}

private:

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

void buildLib(Ctx ctx, Section lib, string link) {
  auto root = lib.get("root");
  auto srcs = resolveGlobs(lib.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto tgtpath = rel2abs(std.path.join(libDir(ctx), libpre ~ tgtName(ctx, lib) ~ libsuf));
  writeln("lib: ", tgtpath);
  auto cmd = fmtString("dmd -lib %s -of%s %s %s",
    join(ctx.args, " "), tgtpath, join(srcs, " "), link);
  execCmdInDir(cmd, root);
}

void buildBin(Ctx ctx, Section bin, string link) {
  auto root = bin.get("root");
  auto srcs = resolveGlobs(bin.get("srcs"), root);
  enforce(!srcs.empty, new Exception("No sources found"));

  auto tgtpath = rel2abs(std.path.join(binDir(ctx), binpre ~ tgtName(ctx, bin) ~ binsuf));
  writeln("bin: ", tgtpath);
  auto cmd = fmtString("dmd %s -of%s %s %s",
    join(ctx.args, " "), tgtpath, join(srcs, " "), link);
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

string libDir(Ctx ctx) {
  return "lib" ~ to!string(ctx.dflags.wordsize);
}

string binDir(Ctx ctx) {
  return "bin" ~ to!string(ctx.dflags.wordsize);
}

string tgtName(Ctx ctx, Section tgt) {
  return tgt.get("target") ~ ctx.dflags.suffix;
}
