module dpk.util;

import std.array, std.exception, std.file, std.format,
  std.functional, std.path, std.regex, std.string, std.c.process;

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

void execCmd(string cmd, bool ignoreRC=false) {
  enforce(std.c.process.system(toStringz(cmd)) == 0 || ignoreRC,
    new Exception(fmtString("Error executing cmd: \n\n %s", cmd)));
}

void execCmdInDir(string cmd, string dir) {
  auto dc = DirChanger(dir);

  execCmd(cmd);
}

string[] resolveGlobs(alias pred=unaryFun!(q{a.isFile}))(string globs, string root = ".") {
  auto dc = DirChanger(root);

  string[] result;
  foreach(glob; splitter(globs)) {
    bool found;
    if (auto re = globsToRe(glob)) {
      found = true; // not enforced to match for now
      auto matcher = regex(re);
      foreach(DirEntry de; dirEntries(".", SpanMode.depth)) {
        if (pred(de) && !match(de.name, matcher).empty) {
          result ~= de.name;
        }
      }
    } else {
      if (std.file.exists(glob)) {
        result ~= glob;
        found = true;
      }
    }
    enforce(found, "no sources found for " ~ glob);
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

string[] copyRel(string tgtdir, string globs, string root = ".") {
  tgtdir = absolutePath(tgtdir);
  if (!exists(tgtdir))
    mkdirRecurse(tgtdir);
  enforce(isDir(tgtdir), new Exception(
            fmtString("Installation failed, %s exists and is no dir.", tgtdir)));

  auto dc = DirChanger(root);
  auto dirs = resolveGlobs!(unaryFun!(q{a.isDir}))("**");

  string[] createdDirs;
  scope(failure) foreach(dir; createdDirs) { std.file.rmdir(dir); }

  foreach(dir; dirs) {
    auto subdir = buildPath(tgtdir, dir);
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
    auto tgtfile = buildPath(tgtdir, file);
    if (std.file.exists(tgtfile))
      std.file.remove(tgtfile);

    std.file.copy(file, tgtfile);
  }
  string prefixDir(string path) {
    return buildPath(root, chompPrefix(path, "." ~ std.path.dirSeparator));
  }
  return apply!prefixDir(files);
}

bool isDirEmpty(string dir) {
  // @@ BUG @@ directly returning false from foreach is broken
  bool res = true;
  foreach(string _; dirEntries(dir, SpanMode.shallow)) {
    res = false;
    break;
  }
  return res;
}

void removeFile(string file) {
  assert(std.path.isAbsolute(file));
  try {
    std.file.remove(file);
    auto dir = dirName(file);
    while (isDirEmpty(dir)) {
      std.file.rmdir(dir);
      dir = dirName(dir);
    }
  } catch (Exception e) {
    std.stdio.stderr.writeln(e.toString());
  }
}

string __iniFilePath;
string __tmpFile;
static ~this() {
  if (__tmpFile)
    removeFile(__tmpFile);
}

string dmdIniFilePath() {
  if (__iniFilePath)
    return __iniFilePath;

  __tmpFile = absolutePath("__dmd_config_dump");
  std.process.system("dmd -v nonexistentfile > " ~ __tmpFile);
  auto f = std.stdio.File(__tmpFile, "r");
  string inifile;
  foreach(line; f.byLine()) {
    if (!line.startsWith("config"))
      continue;
    auto parts = line.split();
    enforce(parts.length > 1, "can't read output of dmd config " ~ line);
    __iniFilePath = parts[1].idup.strip();
    break;
  }
  f.close();
  return __iniFilePath;
}

private:

string globsToRe(string dpkmatcher) {
  bool hasglobs;
  string translateGlobs(Captures!(string, size_t) m) {
    hasglobs = true;
    return enforce(
      m.hit == "**" ? ".+"
      : m.hit == "*" ? "[^" ~ dirSeparator ~ "]+"
      : null
    );
  }
  auto escaped = std.array.replace(dpkmatcher, r".", r"\.");
  version(Windows)
    escaped = std.array.replace(escaped, "/", r"\\");
  auto re = std.regex.replace!(translateGlobs)(
    escaped, regex(r"\*+", "g"));

  return (hasglobs) ? re ~ "$" : null;
}

unittest {
  bool matches(string pattern, string path) {
    if (auto re = globsToRe(pattern))
      return !match(path, regex(re)).empty;
    return false;
  }
  version(Windows) {
    assert(matches("foo/**.d", r"C:\foo\1\2\3\src.d"));
    assert(matches("foo/*", r"D:\foo\a"));
    assert(!matches("foo/*", r"C:\foo\"));
    assert(matches("foo/**", r"C:\foo\a"));
    assert(!matches("foo/**", r"C:\foo\"));
    assert(matches("foo/b**/src.d", r"C:\foo\bar\funk\src.d"));
    assert(matches("foo/b**src.d", r"C:\foo\bar\funk\src.d"));
  } else {
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
  }
}
