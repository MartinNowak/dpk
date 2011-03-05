module dpk.build;

import std.array, std.conv;
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

void buildLib(Ctx ctx, Section lib, string link) {
  std.stdio.writeln("buildLib", lib, link);
}

void buildBin(Ctx ctx, Section bin, string link) {
  std.stdio.writeln("buildBin", bin, link);
  std.stdio.writeln(ctx.installedPkgs());
}

string depFlags(Ctx ctx, Section target) {
  auto deps = split(target.get("depends"));
  string links = fmtString("-L-L%s ", linkPath(ctx));
  if (deps.length) {
    foreach(dep; deps) {
      if (auto cfgname = findPkgByName(ctx, dep)) {
        auto pkgdesc = loadPkgDesc(ctx, cfgname);
        foreach(lib; pkgdesc.sectsByType!("lib")())
          links ~= linkFlags(ctx, lib);
      } else
        throw new Exception(fmtString("Missing pkg dependecy %s", dep));
    }
  }
  return links;
}

string linkPath(Ctx ctx) {
  return installPath(ctx, "lib" ~ to!string(ctx.dflags.wordsize));
}

string linkFlags(Ctx ctx, Section lib) {
  return fmtString("-L-l%s%s ", lib.get("target"), ctx.dflags.suffix);
}
