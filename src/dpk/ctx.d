module dpk.ctx;

import std.algorithm, std.array, std.bitmanip, std.conv, std.functional, std.path, std.process;
import dpk.config, dpk.dflags, dpk.pkgdesc, dpk.util;

class Ctx {
  string[] _cmdargs;
  string[] _defaultargs;
  string _prefix;
  string[] _installedPkgs;
  Section _dpkcfg;
  PkgDesc _pkgdesc;
  DFlags _dflags;
  bool _sharedLibs;
  string[] installedFiles;

  mixin(bitfields!(
          bool, "hasdefaultargs", 1,
          bool, "hasprefix", 1,
          bool, "hasinstalledPkgs", 1,
          bool, "hasdpkcfg", 1,
          bool, "haspkgdesc", 1,
          bool, "hasdflags", 1,
          bool, "hasshared", 1,
          uint, "", 1,
        ));

  this(string[] args) {
    this._cmdargs = args;
  }

  @property string[] args() {
    return this.dflags.args;
  }

  @property string[] defaultargs() {
    if (!this.hasdefaultargs) {
        this._defaultargs = split(this.dpkcfg.get("defaultargs"));
      this.hasdefaultargs = true;
    }
    return this._defaultargs;
  }

  @property string prefix() {
    if (!this.hasprefix) {
      this._prefix = std.process.environment.get("PREFIX");
      if (this._prefix is null)
        this._prefix = this.dpkcfg.get("prefix");
      this._prefix = std.path.expandTilde(this._prefix);
      this.hasprefix = true;
    }

    return this._prefix;
  }

  @property bool sharedLibs() {
    if (!this.hasshared) {
      auto val = std.process.environment.get("SHARED");
      if (val is null)
        val = this.dpkcfg.get("shared");
      this._sharedLibs = to!bool(val);
      this.hasshared = true;
    }

    return this._sharedLibs;
  }

  @property string[] installedPkgs() {
    if (!this.hasinstalledPkgs) {
      auto confd = buildPath(this.prefix, dpk.install.confdir);
      if (std.file.exists(confd) && std.file.isDir(confd))
        this._installedPkgs = sort(
            apply!baseName(
                resolveGlobs("*.cfg", confd))
        ).release;
      this.hasinstalledPkgs = true;
    }

    return this._installedPkgs;
  }

  @property Section dpkcfg() {
    if (!this.hasdpkcfg) {
      this._dpkcfg = parseConfig(dmdIniFilePath()).get("dpk",
        new Exception("Missing [dpk] section in dmd config \""
          ~ dmdIniFilePath() ~ "\""));
      this.hasdpkcfg = true;
    }

    return this._dpkcfg;
  }

  @property PkgDesc pkgdesc() {
    if (!this.haspkgdesc) {
      this._pkgdesc = loadLocalPkgDesc();
      this.haspkgdesc = true;
    }

    return this._pkgdesc;
  }

  @property DFlags dflags() {
    if (!this.hasdflags) {
      this._dflags = DFlags(this._cmdargs, this.defaultargs);
      this.hasdflags = true;
    }

    return this._dflags;
  }

  @property uint verbose() {
    return this.dflags.verbose;
  }
}
