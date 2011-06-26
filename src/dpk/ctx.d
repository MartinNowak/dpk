module dpk.ctx;

import std.algorithm, std.array, std.bitmanip, std.functional, std.path, std.process;
import dpk.config, dpk.dflags, dpk.pkgdesc, dpk.util;

class Ctx {
  string[] _args;
  string _prefix;
  string[] _installedPkgs;
  Section _dpkcfg;
  PkgDesc _pkgdesc;
  DFlags _dflags;
  string[] installedFiles;

  mixin(bitfields!(
          bool, "hasargs", 1,
          bool, "hasprefix", 1,
          bool, "hasinstalledPkgs", 1,
          bool, "hasdpkcfg", 1,
          bool, "haspkgdesc", 1,
          bool, "hasdflags", 1,
          uint, "", 2,
        ));

  this(string[] args) {
    this._args = args;
  }

  @property string[] args() {
    if (!this.hasargs) {
      if (this._args.empty)
        this._args = split(this.dpkcfg.get("defaultargs"));
      this.hasargs = true;
    }
    return this._args;
  }

  @property string prefix() {
    if (!this.hasprefix) {
      this._prefix = environment.get("PREFIX");
      if (this._prefix is null)
        this._prefix = this.dpkcfg.get("prefix");
      this._prefix = std.path.expandTilde(this._prefix);
      this.hasprefix = true;
    }

    return this._prefix;
  }

  @property string[] installedPkgs() {
    if (!this.hasinstalledPkgs) {
      auto confd = join(this.prefix, dpk.install.confdir);
      if (std.file.exists(confd) && std.file.isDir(confd))
        this._installedPkgs = apply!basename(
          resolveGlobs("*.cfg", confd));
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
      this._dflags = DFlags(this.args);
      this.hasdflags = true;
    }

    return this._dflags;
  }

  @property uint verbose() {
    return this.dflags.verbose;
  }
}
