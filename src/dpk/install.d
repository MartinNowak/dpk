module dpk.install;

import std.algorithm, std.array, std.exception, std.path, std.string;
import dpk.ctx, dpk.util;

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
