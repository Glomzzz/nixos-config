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
assert settings['majjExecutable']
assert 'lazyjj' not in settings['packages']
# Desktop and hotkey launches request GUI frames without blocking; terminal
# callers (EDITOR, git, sudoedit) keep emc's default blocking TTY path.
assert settings['editorShortcut'] == [emc, '--create-frame', '--no-wait']
assert settings['directoryShortcut'] == [emc, '--create-frame', '--no-wait', str(Path(emc).parents[2])]
for name in ('emacs', 'emacsclient', 'emacs-dirvish'):
    entry = settings['desktopEntries'][name]
    assert not entry['terminal'], name
    assert entry['exec'].startswith(emc + ' --create-frame --no-wait '), entry
    assert '--tty' not in entry['exec'], name
assert 'emacs-gui' not in settings['desktopEntries']
# Win+; and Win+' run the fish functions through fish, not a shell.
for shortcut, function, expression in (
        ('calcShortcut', 'calc', '(emc/open-calc)'),
        ('emailShortcut', 'email', '(emc/open-mail)')):
    argv = settings[shortcut]
    # --no-config would skip the function path, so fish could not autoload these.
    assert argv[0].endswith('/bin/fish') and argv[1:] == ['-c', function], argv
    body = settings['fishCalc' if function == 'calc' else 'fishEmail'].strip()
    assert body == emc + " --create-frame --no-wait --eval '" + expression + "'", body
assert settings['associations']['text/plain'] == ['emacsclient.desktop']
assert settings['associations']['inode/directory'] == ['emacs-dirvish.desktop']
assert not any('emacs-gui.desktop' in apps for apps in settings['associations'].values())
print('Blocking editor policy, GUI desktop/hotkey launches, and MIME entries passed')

with tempfile.TemporaryDirectory(prefix='emacs-launchers-') as directory:
    root = Path(directory)
    log = root / 'calls.jsonl'
    stub = root / 'stub.py'
    stub.write_text(f'#!{sys.executable}\n' + '''import json, os, pathlib, sys
kind = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['EMC_TEST_LOG'], 'a') as stream:
    stream.write(json.dumps([kind, args]) + '\\n')
pathlib.Path(os.environ['EMC_TEST_CWD']).write_text(os.getcwd())
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
    majj = root / 'majj'
    source = Path(settings['majjWrapper']).read_text()
    assert source.count(emc) == 1
    majj.write_text(source.replace(emc, str(wrapper)))
    majj.chmod(0o755)
    client_cwd = root / 'client-cwd'

    def invoke(args=(), *, terminal=True, probe='ok', active='yes', failure='0', desktop=True,
               launcher=wrapper, cwd=None):
        log.write_text('')
        environment = dict(os.environ, EMACSCLIENT=str(root / 'client'),
                           EMC_TEST_LOG=str(log), EMC_TEST_PROBE=probe,
                           EMC_TEST_CWD=str(client_cwd),
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
                process = subprocess.Popen([launcher, *args], env=environment, cwd=cwd,
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
            result = subprocess.run([launcher, *args], env=environment, cwd=cwd,
                                    capture_output=True, text=True, timeout=10)
            code, text = result.returncode, result.stdout + result.stderr
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

    # Majutsu must use this same managed, blocking TTY path. Directory names
    # are passed by chdir, never interpolated into an executable Lisp form.
    expression = None
    workspace = root / 'workspace "quotes" \\backslash\n中文'
    workspace.mkdir()
    for arguments, cwd, expected in (([], workspace, workspace),
                                     ([workspace.name], root, workspace),
                                     ([str(workspace)], root, workspace)):
        args = client_args(arguments, launcher=majj, cwd=cwd)
        assert args[1] == '--eval' and args[-2:] == ['--tty', '--suppress-output'], args
        assert '--no-wait' not in args and '--create-frame' not in args, args
        assert Path(client_cwd.read_text()) == expected
        if expression is None:
            expression = args[2]
            assert '(majutsu-log default-directory)' in expression
        else:
            assert args[2] == expression, args
    for arguments in (['--help'], ['-h'], ['one', 'two'], [str(root / 'missing')]):
        code, text, calls = invoke(arguments, launcher=majj, terminal=False)
        assert not calls, calls
        if arguments[0] in ('--help', '-h'):
            assert code == 0 and 'Usage: majj' in text
        else:
            assert code != 0
    code, _, calls = invoke(launcher=majj, terminal=False, cwd=workspace)
    assert code == 0 and calls == [['kitty', [
        '--class', 'emacs-terminal', '--override', 'confirm_os_window_close=0',
        str(wrapper), '--eval', expression, '--tty', '--suppress-output']]], calls
    assert Path(client_cwd.read_text()) == workspace
    code, text, calls = invoke(launcher=majj, terminal=False, desktop=False)
    assert code != 0 and not calls and 'attach a TTY' in text
print('Managed Emacs/Majutsu launchers, directories, blocking, terminal handoff, and restart-safety checks passed')
