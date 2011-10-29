module dpk.pkgdesc;

import std.conv, std.file, std.path, std.stdio, std.string;
import dpk.config, dpk.ctx, dpk.install, dpk.util;

PkgDesc loadPkgDesc(Ctx ctx, string pkgbasename) {
  auto descpath = installPath(ctx, dpk.install.confdir, pkgbasename);
  if (!std.file.exists(descpath) || !std.file.isFile(descpath)) {
    throw new Exception(fmtString("Missing file %s.", descpath));
  }
  return PkgDesc(parseConfig(descpath));
}

PkgDesc loadLocalPkgDesc() {
  return PkgDesc(parseConfig(buildPath(curdir, "dpk.cfg")));
}

struct PkgDesc {
  Config config;
  alias config this;

  @property string toString() const {
    return fmtString("PkgDesc %s:\n%s", this.pkgSect().get("name", ""),
      to!string(this.config));
  }

  @property string name() const {
    return toLower(this.pkgSect().get("name"));
  }

private:
  Section pkgSect() const {
    return (cast(Config)config).get("pkg", new Exception("PkgDesc is missing [pkg] section."));
  }
}
