module dpk.install;

import std.algorithm, std.array, std.exception, std.file, std.path, std.string;
import dpk.config, dpk.ctx, dpk.util;

string findPkgByName(Ctx ctx, string pkgname) {
  auto not = (string e) { return !std.algorithm.startsWith(tolower(e), tolower(pkgname)); };
  auto matches = std.algorithm.partition!(not)(ctx.installedPkgs);
  enforce(matches.length <= 1,
    new Exception(fmtString("Ambiguous package %s matches %s.", pkgname, matches)));
  return matches.empty ? null : matches.front;
}

string installPath(Ctx ctx, string subdir, string relpath=null) {
  return std.path.join(std.path.join(ctx.prefix, subdir), relpath);
}

void installPkgDesc(Ctx ctx) {
  auto pkgdesc = ctx.pkgdesc;
  pkgdesc.sections ~= makeInstallSect(ctx);
  std.stdio.writeln(pkgdesc);
  auto pkgsect = pkgdesc.get("pkg");
  auto pkgname = fmtString("%s-%s.cfg", pkgsect.get("name"), pkgsect.get("version"));
  auto dpkdir = installPath(ctx, "dpk");
  if (!std.file.exists(dpkdir))
    mkdirRecurse(dpkdir);
  writeConfig(pkgdesc, join(dpkdir, pkgname));
}

Section makeInstallSect(Ctx ctx) {
  Section install;
  install.type = "install";
  install["files"] = std.array.join(ctx.installedFiles, " ");
  return install;
}
