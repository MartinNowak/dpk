module dpk.config;

import std.algorithm, std.array, std.conv, std.exception, std.metastrings,
  std.regex, std.stream, std.string;
import dpk.util : fmtString;

struct Config {
  Section[] sections;

  @property string toString() const {
    return to!string(this.sections);
  }

  Section get(string type, lazy Section def=Section()) {
    auto sect = findSect(type);
    return sect.empty ? def : sect.front;
  }

  Section get(string type, lazy Exception exc) {
    auto sect = findSect(type);
    enforce(!sect.empty, exc);
    return sect.front;
  }

  bool has(string type) const {
    return !(cast(Config)this).findSect(type).empty;
  }

  auto sectsByType(string type)() {
    return std.algorithm.filter!(Format!("a.type == \"%s\"", type))(this.sections);
  }

private:
  Section[] findSect(string type) {
    return std.algorithm.find!("a.type == b")(this.sections.save, type);
  }
}

struct Section {
  string type;
  string[string] props;
  alias props this;

  @property string toString() const {
    return "[" ~ type ~"]\n" ~ to!string(this.props);
  }

  string get(string key) const {
    return this.props.get(key, this.defaults(key));
  }

  string get(string key, lazy string def) const {
    return this.props.get(key, def);
  }

  string get(string key, lazy Exception exc) const {
    enforce(key in this.props, exc);
    return this.props[key];
  }

  //! TODO: separate defaults from configparser
  string defaults(string key) const {
    enum bindefs = ["install" : "true", "docs" : "false", "imports" : "false", "root" : "."];
    enum libdefs = ["install" : "true", "docs" : "true", "imports" : "true", "root" : ".", "shared" : "false"];
    enum hdrdefs = ["install" : "false", "docs" : "true", "imports" : "true", "root" : "."];
    enum anydefs = ["install" : "false", "docs" : "false", "imports" : "false", "root" : "."];

    // workaround @@@ BUG 5675 @@@
    switch (this.type) {
    case "bin":
      return key in bindefs ? bindefs[key] : "";
    case "lib":
      return key in libdefs ? libdefs[key] : "";
    case "headers":
      return key in hdrdefs ? hdrdefs[key] : "";
    default:
      return key in anydefs ? anydefs[key] : "";
    }
  }
}

package:

Config parseConfig(string filepath) {
  scope auto cfgstream = new std.stream.File(filepath);

  Config config;
  Section curSect;
  bool insection;
  auto sectRe = regex(sectReS);
  auto propRe = regex(propReS);

  foreach(ref char[] line; cfgstream) {
    if (line.empty)
      continue;

    if (insection) {
      auto m = match(line, propRe);
      if (!m.empty) {
        auto prop = strip(m.captures[1]);
        toLowerInPlace(prop);
        auto val = strip(m.captures[2]);
        curSect[prop.idup] = chompPrefix(chomp(val, "\""), "\"").idup;
      } else if (!match(line, sectRe).empty) {
        config.sections ~= curSect;
        insection = false;
      }
    }
    if (!insection) {
      auto m = match(line, sectRe);
      if (!m.empty) {
        auto name = m.captures[1];
        toLowerInPlace(name);
        curSect = Section(name.idup);
        insection = true;
      }
    }
  }
  if (insection)
    config.sections ~= curSect;
  return config;
}

void writeConfig(Config config, string filepath) {
  scope auto cfgstream = new std.stream.File(filepath, FileMode.OutNew);

  foreach(sect; config.sections) {
    cfgstream.writeLine(fmtString("[%s]", sect.type));
    foreach(k, v; sect.props) {
      cfgstream.writeLine(fmtString("%s = %s", k, v));
    }
  }
}

private:

enum sectReS = r"^\[(.*)\]$";
enum propReS = r"^([^#;]+)=([^#;]+)([#;].*)*$";

unittest {
  assert(match("[Section]", sectReS).captures[1] == "Section");
  assert(match("[ Section ]", sectReS).captures[1] == " Section ");
  assert(match(";[ Section ]", sectReS).empty);
  assert(match("#[ Section ]", sectReS).empty);

  assert(match("key=value", propReS).captures[1] == "key");
  assert(match("key=value", propReS).captures[2] == "value");
  assert(match("key = value", propReS).captures[1] == "key ");
  assert(match("key = value", propReS).captures[2] == " value");
  assert(match("key = val ue", propReS).captures[2] == " val ue");
  assert(match("=value", propReS).empty);
  assert(match("key=", propReS).empty);


  assert(match(";key=value", propReS).empty);
  assert(match("key=value;", propReS).captures[2] == "value");
  assert(match("key=val;ue", propReS).captures[2] == "val");
  assert(match("key=val ; comment ue", propReS).captures[2] == "val ");

  assert(match("#key=value", propReS).empty);
  assert(match("key=value#", propReS).captures[2] == "value");
  assert(match("key=val#ue", propReS).captures[2] == "val");
  assert(match("key=val # comment ue", propReS).captures[2] == "val ");

  assert(match("sources = a.d c.d", propReS).captures[2] == " a.d c.d");
}
