"""Pre-flight check before the batched Limul Engine rebuild.

Limul's runtime tree (export/release/windows/bin/assets) is FLATTENED:
Paths.getPreloadPath(f) == 'assets/<f>', so everything from assets/preload sits at the
runtime root, while assets/shared keeps its own shared/ folder and the week folders
(assets/week2 ... assets/week7) sit next to them.

The build copies the project trees into the export, so:
  * a file that exists only in the runtime tree would be LOST by the build,
  * a file that differs is usually the chart editor having saved into the runtime copy.
Both cases have to be resolved before lime build runs.
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_ASSETS = os.path.join(ROOT, 'assets')
PRELOAD = os.path.join(PROJECT_ASSETS, 'preload')
RUNTIME = os.path.join(ROOT, 'export', 'release', 'windows', 'bin', 'assets')
SKIP_DIRS = ('_backup', '_konwersje', '_erect-unused', 'exclude')


def scan(base):
    out = {}
    for dirpath, _dirnames, filenames in os.walk(base):
        for name in filenames:
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, base).replace(os.sep, '/')
            if any(part in SKIP_DIRS for part in rel.split('/')):
                continue
            try:
                with open(path, 'rb') as handle:
                    digest = hashlib.md5(handle.read()).hexdigest()
            except OSError:
                digest = 'ERR'
            out[rel] = digest
    return out


def source_for(top):
    """Which project folder feeds runtime/assets/<top>/ ?"""
    if top == 'shared':
        return os.path.join(PROJECT_ASSETS, 'shared')
    outside = os.path.join(PROJECT_ASSETS, top)          # weekN, fonts, secrets ...
    if os.path.isdir(outside):
        return outside
    return os.path.join(PRELOAD, top)                    # everything else is preload


def main():
    runtime = scan(RUNTIME)
    sources = {}
    for key in runtime:
        sources.setdefault(key.split('/')[0], True)
    project = {}
    for top in sorted(sources):
        folder = source_for(top)
        if not os.path.isdir(folder):
            print('!! runtime has assets/%s/ but no project folder maps to it' % top)
            continue
        for rel, digest in scan(folder).items():
            project['%s/%s' % (top, rel)] = digest
    # files the project has for folders the runtime tree does not carry at all (fonts, ...)
    for top in ('fonts', 'secrets', 'videos', 'songs', 'images', 'data', 'stages', 'characters',
                'music', 'sounds', 'scripts', 'shaders', 'custom_events', 'custom_notetypes'):
        folder = source_for(top)
        if os.path.isdir(folder):
            for rel, digest in scan(folder).items():
                project.setdefault('%s/%s' % (top, rel), digest)

    differ = sorted(k for k in project if k in runtime and project[k] != runtime[k])
    only_project = sorted(k for k in project if k not in runtime)
    only_runtime = sorted(k for k in runtime if k not in project)

    print('project files : %d' % len(project))
    print('runtime files : %d' % len(runtime))
    print()
    print('DIFFER (%d) -- editor saved into bin; decide which copy wins' % len(differ))
    for key in differ[:40]:
        print('    ', key)
    print('ONLY IN PROJECT (%d) -- will appear at the next build' % len(only_project))
    for key in only_project[:40]:
        print('    ', key)
    print('ONLY IN RUNTIME (%d) -- MUST be copied into the project before rebuilding' % len(only_runtime))
    for key in only_runtime[:60]:
        print('    ', key)


if __name__ == '__main__':
    main()
