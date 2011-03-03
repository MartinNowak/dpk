module dpk.pkgdesc;

import std.conv, std.file, std.path, std.stdio;
import dpk.config, dpk.util;

PkgDesc loadPkgDesc(string descpath) {
  if (!std.file.exists(descpath) || !std.file.isFile(descpath)) {
    throw new Exception(fmtString("Missing file %s.", descpath));
  }
  return PkgDesc(parseConfig(descpath));
}

PkgDesc loadLocalPkgDesc() {
  return loadPkgDesc(join(curdir, "dpk.cfg"));
}

struct PkgDesc {
  Config config;

  @property string toString() const {
    return fmtString("PkgDesc %s:\n%s", this.pkgSect().get("name", ""),
      to!string(this.config));
  }

private:
  const(Section) pkgSect() const {
    return config.get("pkg", new Exception("PkgDesc is missing [pkg] section."));
  }
}
