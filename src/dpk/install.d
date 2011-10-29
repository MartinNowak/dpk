module dpk.install;

import std.algorithm, std.array, std.exception, std.file, std.path, std.range, std.string;
import dpk.config, dpk.ctx, dpk.pkgdesc, dpk.util;

string findPkgByName(Ctx ctx, string pkgname) {
  auto not = (string e) { return !std.algorithm.startsWith(toLower(e), toLower(pkgname)); };
  auto matches = std.algorithm.partition!(not)(ctx.installedPkgs);
  enforce(matches.length <= 1,
    new Exception(fmtString("Ambiguous package %s matches %s.", pkgname, matches)));
  return matches.empty ? null : matches.front;
}

enum confdir = "conf.d";

string installPath(Ctx ctx, string subdir, string relpath=null) {
  return buildPath(buildPath(ctx.prefix, subdir), relpath);
}

void installPkgDesc(Ctx ctx) {
  auto pkgdesc = ctx.pkgdesc;

  auto pkgsect = pkgdesc.get("pkg");
  auto pkgname = fmtString("%s-%s.cfg", pkgsect.get("name"), pkgsect.get("version"));
  auto confd = installPath(ctx, confdir);
  if (!std.file.exists(confd))
    mkdirRecurse(confd);

  pkgdesc.sections ~= makeInstallSect(ctx);
  auto pkgdescpath = buildPath(confd, pkgname);
  if (std.file.exists(pkgdescpath))
    mergePkgDescs(pkgdesc, PkgDesc(parseConfig(pkgdescpath)));
  writeConfig(pkgdesc, pkgdescpath);
}

void uninstallPkgDesc(Ctx ctx, string pkgname) {
  removeFile(installPath(ctx, confdir, pkgname));
}

Section makeInstallSect(Ctx ctx) {
  Section install;
  install.type = "install";
  install["files"] = std.array.join(ctx.installedFiles, " ");
  return install;
}

void mergePkgDescs(ref PkgDesc newpkg, PkgDesc existing) {
  auto cat = sort(split(newpkg.get("install")["files"]) ~ split(existing.get("install")["files"]));
  newpkg.get("install")["files"] = join(uniq(cat), " ");
}
