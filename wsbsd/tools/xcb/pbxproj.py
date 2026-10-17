"""Reader for Xcode project files (project.pbxproj, an OpenStep style property list) and the model xcb.py builds from: targets, build phases, file
references resolved to paths, build settings with $(VAR) expansion. Pure Python 3, no Apple tools."""
import os, re

class Parser:
    def __init__(self, text):
        self.s = text; self.i = 0; self.n = len(text)
    def ws(self):
        s, n = self.s, self.n
        while self.i < n:
            c = s[self.i]
            if c in " \t\r\n": self.i += 1
            elif s.startswith("//", self.i):
                j = s.find("\n", self.i); self.i = n if j < 0 else j + 1
            elif s.startswith("/*", self.i):
                j = s.find("*/", self.i + 2); self.i = n if j < 0 else j + 2
            else: break
    def value(self):
        self.ws(); c = self.s[self.i]
        if c == "{": return self.dict()
        if c == "(": return self.array()
        if c == '"': return self.quoted()
        return self.bare()
    def dict(self):
        self.i += 1; d = {}
        while True:
            self.ws()
            if self.s[self.i] == "}": self.i += 1; return d
            k = self.value(); self.ws()
            if self.s[self.i] == "=":
                self.i += 1; v = self.value(); self.ws()
                if self.s[self.i] == ";": self.i += 1
                d[k] = v
            else:
                if self.s[self.i] == ";": self.i += 1
                d[k] = k
    def array(self):
        self.i += 1; a = []
        while True:
            self.ws()
            if self.s[self.i] == ")": self.i += 1; return a
            a.append(self.value()); self.ws()
            if self.s[self.i] == ",": self.i += 1
    def quoted(self):
        s = self.s; self.i += 1; out = []
        while s[self.i] != '"':
            if s[self.i] == "\\":
                self.i += 1; c = s[self.i]
                out.append({"n": "\n", "t": "\t", "r": "\r"}.get(c, c))
            else: out.append(s[self.i])
            self.i += 1
        self.i += 1
        return "".join(out)
    def bare(self):
        m = re.compile(r"[A-Za-z0-9_$/.\-+:@%*<>?!~|&^=\[\]]+").match(self.s, self.i)
        if not m or m.end() == self.i: raise ValueError("pbxproj: unexpected %r at %d" % (self.s[self.i:self.i + 20], self.i))
        self.i = m.end()
        return m.group(0)

def load(path):
    with open(path, encoding="utf-8") as f: return Parser(f.read()).value()

class Project:
    def __init__(self, xcodeproj):
        self.xcodeproj = os.path.abspath(xcodeproj)
        self.root = os.path.dirname(self.xcodeproj)                       # SOURCE_ROOT is the directory holding the .xcodeproj
        d = load(os.path.join(self.xcodeproj, "project.pbxproj"))
        self.objs = d["objects"]; self.main = self.objs[d["rootObject"]]
        self._parent = {}
        for k, o in self.objs.items():
            if o.get("isa") in ("PBXGroup", "PBXVariantGroup", "XCVersionGroup"):
                for c in o.get("children", []): self._parent[c] = k
    def targets(self): return [self.objs[t] | {"id": t} for t in self.main["targets"]]
    def target(self, name):
        for t in self.targets():
            if t.get("name") == name: return t
        return None
    # ---- paths ----
    def path_of(self, oid, built=None):
        o = self.objs[oid]; p = o.get("path", ""); st = o.get("sourceTree", "<group>")
        if st == "SOURCE_ROOT": return os.path.normpath(os.path.join(self.root, p))
        if st == "<absolute>": return p
        if st == "<group>":
            par = self._parent.get(oid)
            base = self.path_of(par) if par else self.root
            return os.path.normpath(os.path.join(base, p)) if p else base
        if st == "BUILT_PRODUCTS_DIR": return "$(BUILT_PRODUCTS_DIR)/" + p
        if st == "SDKROOT": return "$(SDKROOT)/" + p
        if st == "DEVELOPER_DIR": return "$(DEVELOPER_DIR)/" + p
        return p
    # ---- build settings ----
    def settings(self, target, config="Release"):
        s = {}
        def cl(oid):
            for c in self.objs[self.objs[oid]["buildConfigurationList"]]["buildConfigurations"]:
                co = self.objs[c]
                if co["name"] == config: return co.get("buildSettings", {})
            return {}
        s.update(cl(self.main_id()) if False else self._proj_settings(config))
        s.update(cl(target["id"]))
        return s
    def main_id(self): return [k for k, o in self.objs.items() if o.get("isa") == "PBXProject"][0]
    def _proj_settings(self, config):
        o = self.objs[self.objs[self.main_id()]["buildConfigurationList"]]
        for c in o["buildConfigurations"]:
            if self.objs[c]["name"] == config: return dict(self.objs[c].get("buildSettings", {}))
        return {}
    # ---- phases ----
    def phase(self, target, isa):
        for p in target.get("buildPhases", []):
            if self.objs[p]["isa"] == isa: return self.objs[p]
        return None
    def phase_files(self, phase):
        out = []
        for b in phase.get("files", []) if phase else []:
            bf = self.objs[b]; fr = bf.get("fileRef")
            if fr and fr in self.objs:
                o = self.objs[fr]
                if o.get("isa") == "PBXVariantGroup":                         # a localized file: one entry per variant (Base.lproj/X.xib, de.lproj/X.strings, ...)
                    for c in o.get("children", []):
                        if c in self.objs: out.append((self.path_of(c), self.objs[c], bf.get("settings", {})))
                else: out.append((self.path_of(fr), o, bf.get("settings", {})))
        return out
    def dependencies(self, target):
        out = []
        for d in target.get("dependencies", []):
            tid = self.objs[d].get("target")
            if tid: out.append(self.objs[tid] | {"id": tid})
        return out

_var = re.compile(r"\$[({]([A-Za-z0-9_]+)(?::[a-zA-Z]+)?[)}]")
def expand(val, env, depth=0):
    if isinstance(val, list): return [expand(v, env, depth) for v in val]
    if not isinstance(val, str) or depth > 8: return val
    def sub(m):
        k = m.group(1)
        if k == "inherited": return env.get("__inherited__", "")
        v = env.get(k)
        if v is None: return ""
        return " ".join(v) if isinstance(v, list) else expand(v, env, depth + 1)
    return _var.sub(sub, val)
