module dpk.util;

import std.array, std.exception, std.file, std.format, std.functional, std.path, std.regex, std.string;

string fmtString(Args...)(string fmt, Args args) {
  auto app = appender!string();
  formattedWrite(app, fmt, args);
  return app.data;
}

Range apply(alias fun, Range)(Range range) {
  foreach(ref elem; range)
    elem = fun(elem);
  return range;
}

void execCmd(string cmd) {
  enforce(!std.process.system(cmd),
    new Exception(fmtString("Error executing cmd: \n\n %s", cmd)));
}

void execCmdInDir(string cmd, string dir) {
  auto dc = DirChanger(dir);

  execCmd(cmd);
}

string[] resolveGlobs(alias pred=unaryFun!(q{a.isFile}))(string globs, string root = std.path.curdir) {
  auto dc = DirChanger(root);

  string[] result;
  foreach(glob; splitter(globs)) {
    auto matcher = reMatcher(glob);
    foreach(DirEntry de; dirEntries(std.path.curdir, SpanMode.depth)) {
      if (pred(de) && !match(de.name, matcher).empty) {
        result ~= de.name;
      }
    }
  }
  return result;
}

struct DirChanger {
  string olddir;
  this(string newdir) {
    this.olddir = std.file.getcwd();
    std.file.chdir(newdir);
  }
  ~this() { std.file.chdir(this.olddir); }
}

string[] copyRel(string tgtdir, string globs, string root = std.path.curdir) {
  tgtdir = rel2abs(tgtdir);
  if (!exists(tgtdir))
    mkdirRecurse(tgtdir);
  enforce(isDir(tgtdir), new Exception(
            fmtString("Installation failed, %s exists and is no dir.", tgtdir)));

  auto dc = DirChanger(root);
  auto dirs = resolveGlobs!(unaryFun!(q{a.isDir}))("**");

  string[] createdDirs;
  scope(failure) foreach(dir; createdDirs) { std.file.rmdir(dir); }

  foreach(dir; dirs) {
    auto subdir = join(tgtdir, dir);
    if (!exists(subdir)) {
      createdDirs ~= subdir;
      mkdirRecurse(subdir);
    } else {
      enforce(isDir(subdir), new Exception(
                fmtString("Installation failed, %s exists and is no dir.", subdir)));
    }
  }

  auto files = resolveGlobs!(unaryFun!(q{a.isFile}))(globs);
  foreach(file; files) {
    auto tgtfile = join(tgtdir, file);
    if (std.file.exists(tgtfile))
      std.file.remove(tgtfile);

    std.file.copy(file, tgtfile);
  }
  string prefixDir(string path) {
    return std.path.join(root, chompPrefix(path, std.path.curdir ~ std.path.sep));
  }
  return apply!prefixDir(files);
}

bool isDirEmpty(string dir) {
  foreach(string _; dirEntries(dir, SpanMode.shallow)) {
    return false;
  }
  return true;
}

void removeFile(string file) {
  try {
    std.file.remove(file);
    auto dir = dirname(file);
    while (isDirEmpty(dir)) {
      std.file.rmdir(dir);
      dir = dirname(dir);
    }
  } catch (Exception e) {
    std.stdio.stderr.writeln(e.toString());
  }
}

private:

auto reMatcher(string dpkmatcher) {
  enum string seps = std.path.sep ~ std.path.altsep;

  string translateGlobs(RegexMatch!string m) {
    return enforce(
      m.hit == "**" ? ".+"
      : m.hit == "*" ? "[^" ~ seps ~ "]+"
      : null
    );
  }
  auto escaped = std.array.replace(dpkmatcher, r".", r"\.");
  auto re = std.regex.replace!(translateGlobs)(
    escaped, regex(r"\*\*|\*", "g"));

  return regex(re ~ "$");
}

unittest {
  bool matches(string pattern, string path) {
    return !match(path, reMatcher(pattern)).empty;
  }
  assert(matches("foo/b*/src.d", "foo/bar/src.d"));
  assert(matches("foo/b**/src.d", "foo/bar/src.d"));
  assert(matches("foo/b**/src.d", "foo/bar/funk/src.d"));
  assert(matches("foo/b**src.d", "foo/bar/funk/src.d"));
  assert(matches("foo/b**/funk/src.d", "foo/bar/funk/src.d"));
  assert(matches("foo/*.d", "foo/a.d"));
  assert(matches("foo/*", "foo/a"));
  assert(!matches("foo/*/*", "foo/a"));
  assert(!matches("foo/*", "foo/"));
  assert(!matches("foo/*.d", "foo/bar/a.d"));
  assert(matches("foo/**", "foo/a"));
  assert(!matches("foo/**", "foo/"));
  assert(!matches("foo/**/.d", "foo/src.d"));
  assert(matches("foo/**.d", "foo/src.d"));
  assert(matches("foo/**.d", "foo/1/2/3/src.d"));

  version(Windows) {
    assert(matches("foo/**.d", "foo\\1\\2\\3\\src.d"));
    assert(matches("foo/*", "foo\\a"));
    assert(!matches("foo/*", "foo\\"));
    assert(matches("foo/**", "foo\\a"));
    assert(matches("foo/**", "foo\\"));
    assert(matches("foo/b**/src.d", "foo\\bar\\funk\\src.d"));
    assert(matches("foo/b**src.d", "foo\\bar\\funk\\src.d"));
  }
}
