module dpk.build;

import dpk.pkgdesc;

int runBuild(string[] args) {
  auto pkgDesc = loadLocalPkgDesc();
  std.stdio.writeln(pkgDesc);
  return 0;
}
