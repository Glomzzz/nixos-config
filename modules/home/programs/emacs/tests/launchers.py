"""Check terminal-first policy and exercise the managed wrapper with safe mocks."""

import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import tempfile
import termios

settings = json.loads(Path(sys.argv[1]).read_text())
emc = settings['emc']
for key in ('EDITOR', 'VISUAL', 'SUDO_EDITOR'):
    assert settings['environment'][key] == emc, key
    assert settings['niriEnvironment'][key] == emc, key
assert settings['gitEditor'] == emc
assert not settings['generatedClient']
assert settings['editorShortcut'] == [emc]
assert settings['directoryShortcut'] == [emc, str(Path(emc).parents[2])]
for name in ('emacs', 'emacsclient', 'emacs-dirvish'):
    entry = settings['desktopEntries'][name]
    # The managed wrapper, not the desktop, must create the dedicated Kitty.
    assert not entry['terminal'], name
    assert entry['exec'].startswith(emc + ' --tty '), entry
    assert '--no-wait' not in entry['exec'], name
entry = settings['desktopEntries']['emacs-gui']
assert not entry['terminal']
assert entry['exec'] == emc + ' --create-frame --no-wait %F'
assert settings['associations']['text/plain'] == ['emacsclient.desktop']
assert settings['associations']['inode/directory'] == ['emacs-dirvish.desktop']
assert not any('emacs-gui.desktop' in apps for apps in settings['associations'].values())
print('Terminal-first editor, Git, shortcuts, MIME entries, and explicit GUI policy passed')

with tempfile.TemporaryDirectory(prefix='emacs-launchers-') as directory:
    root = Path(directory)
    log = root / 'calls.jsonl'
    stub = root / 'stub.py'
    stub.write_text(f'#!{sys.executable}\n' + '''import json, os, pathlib, sys
kind = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['EMC_TEST_LOG'], 'a') as stream:
    stream.write(json.dumps([kind, args]) + '\\n')
if kind == 'client' and any('emc/launcher-state' in arg for arg in args):
    probe = os.environ.get('EMC_TEST_PROBE', 'ok')
    if probe == 'ERROR':
        sys.exit(1)
    print(probe)
elif kind == 'systemctl':
    if 'is-active' in args:
        sys.exit(0 if os.environ.get('EMC_TEST_ACTIVE') == 'yes' else 3)
    sys.exit(int(os.environ.get('EMC_TEST_SERVICE_FAILURE', '0')))
''')
    stub.chmod(0o755)
    for name in ('client', 'systemctl', 'kitty'):
        (root / name).symlink_to(stub)
    source = Path(settings['wrapper']).read_text()
    assert source.count('/run/current-system/sw/bin/systemctl') == 1
    assert source.count(settings['kitty']) == 1
    source = source.replace('/run/current-system/sw/bin/systemctl', str(root / 'systemctl'))
    source = source.replace(settings['kitty'], str(root / 'kitty'))
    wrapper = root / 'emc'
    wrapper.write_text(source)
    wrapper.chmod(0o755)

    def invoke(args=(), *, terminal=True, probe='ok', active='yes', failure='0', desktop=True):
        log.write_text('')
        environment = dict(os.environ, EMACSCLIENT=str(root / 'client'),
                           EMC_TEST_LOG=str(log), EMC_TEST_PROBE=probe,
                           EMC_TEST_ACTIVE=active, EMC_TEST_SERVICE_FAILURE=failure)
        for key in ('DISPLAY', 'WAYLAND_DISPLAY'):
            environment.pop(key, None)
        if desktop:
            environment['WAYLAND_DISPLAY'] = 'mock-wayland'
        if terminal:
            master, slave = pty.openpty()

            def controlling_terminal():
                os.setsid()
                fcntl.ioctl(0, termios.TIOCSCTTY, 0)

            try:
                process = subprocess.Popen([wrapper, *args], env=environment,
                                           stdin=slave, stdout=slave, stderr=slave,
                                           preexec_fn=controlling_terminal)
                os.close(slave)
                slave = None
                process.wait(timeout=10)
                output = bytearray()
                while select.select([master], [], [], 0)[0]:
                    try:
                        block = os.read(master, 65536)
                    except OSError as error:
                        if error.errno == errno.EIO:
                            break
                        raise
                    if not block:
                        break
                    output.extend(block)
                code, text = process.returncode, output.decode()
            finally:
                if slave is not None:
                    os.close(slave)
                os.close(master)
        else:
            result = subprocess.run([wrapper, *args], env=environment,
                                    capture_output=True, text=True, timeout=10)
            code, text = result.returncode, result.stderr
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        return code, text, calls

    def client_args(args=(), **kwargs):
        code, text, calls = invoke(args, **kwargs)
        assert code == 0, (text, calls)
        assert calls[-1][0] == 'client', calls
        return calls[-1][1]

    for desktop in (False, True):
        args = client_args(['file with spaces.txt'], desktop=desktop)
        assert args[-2:] == ['--tty', 'file with spaces.txt'], args
        assert args[0].startswith('--alternate-editor=') and not args[0].endswith('='), args
    assert client_args()[-1] == '--tty'
    assert '--tty' not in client_args(['--create-frame', '--no-wait', 'file.txt'])
    assert '--tty' not in client_args(['--eval', '(+ 1 2)'])
    assert '--tty' not in client_args(['-e', '(+ 1 2)'])
    assert '--tty' in client_args(['--socket-name', '--eval', 'file.txt'])
    assert client_args(['--', '--create-frame'])[-3:] == ['--tty', '--', '--create-frame']
    code, text, calls = invoke(['--no-wait', 'file.txt'])
    assert code != 0 and not calls and 'must wait' in text
    for option in ('--help', '--version'):
        code, _, calls = invoke([option], terminal=False)
        assert code == 0 and calls == [['client', [option]]], calls

    # Only the daemon can affirm that a stale restart is safe.
    code, _, calls = invoke(probe='stale')
    assert code == 0 and ['systemctl', ['--user', 'restart', 'emacs.service']] in calls
    for probe in ('ERROR', 'unverified'):
        code, text, calls = invoke(probe=probe)
        assert code != 0 and 'refusing to restart' in text, (text, calls)
        assert not any('restart' in args for kind, args in calls), calls
    code, _, calls = invoke(probe='ERROR', active='no')
    assert code == 0 and ['systemctl', ['--user', 'start', 'emacs.service']] in calls
    code, _, calls = invoke(probe='stale', failure='1')
    assert code != 0 and calls[-1][0] == 'systemctl', calls

    # A detached desktop call obtains a TTY before touching the daemon.
    # Emacs-only close policy must cover both default and desktop --tty calls.
    for arguments in (['file with spaces.txt'], ['--tty', 'file with spaces.txt']):
        code, _, calls = invoke(arguments, terminal=False)
        assert code == 0 and calls == [['kitty', [
            '--class', 'emacs-terminal', '--override', 'confirm_os_window_close=0',
            str(wrapper), '--tty', 'file with spaces.txt']]], calls
    code, text, calls = invoke(terminal=False, desktop=False)
    assert code != 0 and not calls and 'attach a TTY' in text
    assert '--tty' not in client_args(['--create-frame'], terminal=False)
print('Managed launcher frontend, blocking, terminal handoff, and restart-safety checks passed')
