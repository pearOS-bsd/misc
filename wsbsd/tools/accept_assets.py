#!/usr/bin/env python3
"""Acceptance check of the designer's asset catalogues and their installation.

  accept_assets.py [--assets DIR] [--cardump PATH] [--report FILE] [--install DEST]

DIR (default ../assets-designer next to the repository) holds orig/<Folder>/<file>.car (the system's own catalogues) and mod/<Folder>/<file>.car (the replacements). Every mod file is compared with its
original rendition by rendition (a rendition is identified by its name and the complete attribute key, the attributes of coreui/car.h): a missing rendition, a different size, layout kind or
pixel format fails the file; a rendition the original does not have is reported as extra (not a failure). A file that cannot be read fails. With --install the accepted mods and, for everything else,
the originals are copied to DEST (default /usr/local/share/wsbsd/coreui) under the names the code looks for: Assets.car of a folder becomes <Folder>.car, other files keep their name; so the
replacement is found before the original without any change of the lookup order.
Exit status 1 when a mod file failed."""
import argparse, collections, os, shutil, subprocess, sys

here = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument('--assets', default=os.path.normpath(os.path.join(here, '..', '..', '..', 'assets-designer')))
ap.add_argument('--cardump', default=os.path.join(here, '..', 'coreui', 'cardump'))
ap.add_argument('--report')
ap.add_argument('--install', nargs='?', const='/usr/local/share/wsbsd/coreui')
a = ap.parse_args()

def renditions(path):
    env = dict(os.environ, CAR_TSV='1', CAR_HASH='1')
    p = subprocess.run([a.cardump, path], capture_output=True, text=True, env=env)
    if p.returncode != 0: return None
    out = collections.Counter(); info = {}; hashes = {}
    for line in p.stdout.splitlines():
        f = line.split('\t')
        if len(f) < 8: continue
        key = (f[0], f[6])
        out[key] += 1; info.setdefault(key, []).append((f[1], f[2], f[4], f[5])); hashes.setdefault(key, []).append(f[8] if len(f) > 8 else '')
    return out, info, hashes

def compare(orig, mod):
    (oc, oi, oh), (mc, mi, mh) = orig, mod
    missing = [k for k in oc if mc[k] < oc[k]]; extra = [k for k in mc if oc[k] < mc[k]]
    changed = []
    for k in oc:
        if k in mi:
            for i, (o, m) in enumerate(zip(oi[k], mi[k])):
                if o != m: changed.append((k, o, m)); break
    same = diff = 0                                             # the content: the payload of every rendition the two catalogues share (a delivery that only repacks the originals changes nothing on the screen)
    for k in oc:
        if k in mh:
            for o_, m_ in zip(oh[k], mh[k]):
                if o_ == m_: same += 1
                else: diff += 1
    return missing, extra, changed, (same, diff)

lines = []; failed = []; accepted = set(); tot_same = [0]; tot_diff = [0]
def say(s): print(s); lines.append(s)
mods = []
for root, _, files in os.walk(os.path.join(a.assets, 'mod')):
    for f in sorted(files):
        if f.endswith('.car'): mods.append(os.path.join(root, f))
if not mods: say('no replacement found in %s/mod: nothing to check' % a.assets)
for m in sorted(mods):
    rel = os.path.relpath(m, os.path.join(a.assets, 'mod')); o = os.path.join(a.assets, 'orig', rel)
    if not os.path.exists(o): say('FAIL %s: no original in orig/ (the file and folder names must match)' % rel); failed.append(rel); continue
    ro, rm = renditions(o), renditions(m)
    if ro is None: say('FAIL %s: the original cannot be read' % rel); failed.append(rel); continue
    if rm is None: say('FAIL %s: the replacement is not a readable catalogue' % rel); failed.append(rel); continue
    missing, extra, changed, (same, diff) = compare(ro, rm); tot_same[0] += same; tot_diff[0] += diff
    bad = bool(missing or changed)
    say('%s %s: %d renditions in the original, %d in the replacement; %d missing, %d changed, %d extra; content: %d renditions identical, %d different' % ('FAIL' if bad else 'ok  ', rel, sum(ro[0].values()), sum(rm[0].values()), len(missing), len(changed), len(extra), same, diff))
    for k in missing[:20]: say('    missing  %s [%s]' % k)
    for k, o_, m_ in changed[:20]: say('    changed  %s: %sx%s %s layout %s -> %sx%s %s layout %s' % (k[0], o_[0], o_[1], o_[2], o_[3], m_[0], m_[1], m_[2], m_[3]))
    for k in extra[:10]: say('    extra    %s [%s]' % k)
    if bad: failed.append(rel)
    else: accepted.add(rel)
say('content of all the replacements: %d renditions identical to the originals, %d different%s' % (tot_same[0], tot_diff[0], ' (NOTHING CHANGED: the files only repack the originals)' if mods and not tot_diff[0] else ''))
if a.report: open(a.report, 'w').write('\n'.join(lines) + '\n')
if a.install:
    n_mod = n_orig = 0
    os.makedirs(a.install, exist_ok=True)
    for root, _, files in os.walk(os.path.join(a.assets, 'orig')):
        for f in sorted(files):
            if not f.endswith('.car'): continue
            rel = os.path.relpath(os.path.join(root, f), os.path.join(a.assets, 'orig')); folder = os.path.dirname(rel)
            dst = os.path.join(a.install, (folder + '.car') if f == 'Assets.car' else f)
            src = os.path.join(a.assets, 'mod', rel) if rel in accepted else os.path.join(a.assets, 'orig', rel)
            if os.path.exists(dst) and os.path.getsize(dst) == os.path.getsize(src) and os.path.getmtime(dst) >= os.path.getmtime(src): continue
            shutil.copyfile(src, dst); n_mod += rel in accepted; n_orig += rel not in accepted
    say('installed to %s: %d replacements, %d originals' % (a.install, n_mod, n_orig))
sys.exit(1 if failed else 0)
