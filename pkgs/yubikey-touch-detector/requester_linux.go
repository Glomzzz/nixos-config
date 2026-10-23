package notifier

// Requester attribution is advisory UI metadata, never an authentication check.
// Only executable names are read: no command lines, PINs, payloads or websites.
import (
	"encoding/binary"
	"html"
	"net"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"

	"golang.org/x/sys/unix"
)

var requesterState = struct {
	sync.Mutex
	pids    map[string]int
	devices map[uint64]string
	pam     map[string]int
}{pids: make(map[string]int), devices: make(map[uint64]string), pam: make(map[string]int)}

// PeerPID uses kernel credentials rather than trusting Assuan client options.
func PeerPID(connection net.Conn) int {
	conn, ok := connection.(*net.UnixConn)
	if !ok {
		return 0
	}
	raw, err := conn.SyscallConn()
	if err != nil {
		return 0
	}
	pid := 0
	err = raw.Control(func(fd uintptr) {
		cred, err := unix.GetsockoptUcred(int(fd), unix.SOL_SOCKET, unix.SO_PEERCRED)
		if err == nil && cred.Uid == uint32(os.Getuid()) {
			pid = int(cred.Pid)
		}
	})
	if err != nil {
		return 0
	}
	return pid
}

func SetRequester(source string, pid int) {
	requesterState.Lock()
	defer requesterState.Unlock()
	if pid > 0 {
		requesterState.pids[source] = pid
	} else {
		delete(requesterState.pids, source)
	}
}

func SetTouchDevice(id uint64, path string, active bool) {
	requesterState.Lock()
	defer requesterState.Unlock()
	if active {
		requesterState.devices[id] = path
	} else {
		delete(requesterState.devices, id)
	}
}

func executableName(proc string, pid int) string {
	target, err := os.Readlink(filepath.Join(proc, strconv.Itoa(pid), "exe"))
	if err != nil {
		return ""
	}
	name := strings.TrimSuffix(filepath.Base(target), " (deleted)")
	name = strings.TrimSuffix(strings.TrimPrefix(name, "."), "-wrapped")
	// Bound and escape untrusted process metadata before inserting it in markup.
	name = strings.Map(func(r rune) rune {
		if r < 32 || r == 127 {
			return -1
		}
		return r
	}, name)
	if len(name) > 80 {
		return ""
	}
	return name
}

func processLabel(proc string, pid int) string {
	name := executableName(proc, pid)
	if name != "gpg" && name != "gpg2" && name != "gpgsm" {
		return name
	}
	// gpg is typically a child of git, jj, sops or pass. Do not walk past a
	// shell and misleadingly name the terminal when gpg was invoked directly.
	status, err := os.ReadFile(filepath.Join(proc, strconv.Itoa(pid), "status"))
	if err != nil {
		return name
	}
	for _, line := range strings.Split(string(status), "\n") {
		if !strings.HasPrefix(line, "PPid:") {
			continue
		}
		parent, _ := strconv.Atoi(strings.TrimSpace(strings.TrimPrefix(line, "PPid:")))
		label := executableName(proc, parent)
		switch label {
		case "", "sh", "bash", "dash", "zsh", "fish", "systemd":
			return name
		}
		return label
	}
	return name
}

func deviceLabels(proc string, devices map[string]bool) []string {
	if len(devices) == 0 {
		return nil
	}
	processes, _ := os.ReadDir(proc)
	labels := make(map[string]bool)
	for _, process := range processes {
		pid, err := strconv.Atoi(process.Name())
		if err != nil || pid == os.Getpid() {
			continue
		}
		fds, _ := os.ReadDir(filepath.Join(proc, process.Name(), "fd"))
		for _, fd := range fds {
			target, err := os.Readlink(filepath.Join(proc, process.Name(), "fd", fd.Name()))
			if err != nil || !devices[target] {
				continue
			}
			// Ignore read-only observers (including other touch detectors).
			info, _ := os.ReadFile(filepath.Join(proc, process.Name(), "fdinfo", fd.Name()))
			writable := false
			for _, line := range strings.Split(string(info), "\n") {
				if strings.HasPrefix(line, "flags:") {
					flags, err := strconv.ParseUint(strings.TrimSpace(strings.TrimPrefix(line, "flags:")), 8, 64)
					writable = err == nil && flags&unix.O_ACCMODE != unix.O_RDONLY
				}
			}
			if writable {
				if label := processLabel(proc, pid); label != "" {
					labels[label] = true
				}
			}
		}
	}
	return sortedLabels(labels)
}

func sortedLabels(labels map[string]bool) []string {
	result := make([]string, 0, len(labels))
	for label := range labels {
		result = append(result, label)
	}
	sort.Strings(result)
	return result
}

func requesterSummary(reasons string) string {
	requesterState.Lock()
	pids := make(map[string]int)
	for source, pid := range requesterState.pids {
		pids[source] = pid
	}
	devices := make(map[string]bool)
	for _, device := range requesterState.devices {
		devices[device] = true
	}
	pam := make(map[string]bool)
	for service, count := range requesterState.pam {
		if count > 0 {
			pam[service] = true
		}
	}
	requesterState.Unlock()

	labels := make(map[string]bool)
	for _, reason := range strings.Split(reasons, ", ") {
		switch reason {
		case "gpg":
			found := false
			for _, pid := range pids {
				if label := processLabel("/proc", pid); label != "" {
					labels[label], found = true, true
				}
			}
			if !found {
				labels["OpenPGP/SSH"] = true
			}
		case "u2f":
			// Root-owned sudo descriptors are intentionally inaccessible. PAM's
			// open/close marker supplies its service name without root privileges.
			candidates := deviceLabels("/proc", devices)
			if len(pam) == 1 && len(candidates) == 0 {
				for service := range pam {
					labels[service] = true
				}
			} else if len(pam) == 0 && len(candidates) == 1 {
				labels[candidates[0]] = true
			} else if len(pam) == 1 && len(candidates) == 1 && pam[candidates[0]] {
				labels[candidates[0]] = true
			} else {
				// HID exposes presence-needed, not the channel's owning process.
				// Multiple openers or simultaneous PAM requests are ambiguous.
				labels["FIDO/WebAuthn"] = true
			}
		case "hmac":
			labels["HMAC challenge-response"] = true
		}
	}
	return html.EscapeString(strings.Join(sortedLabels(labels), " / "))
}

// pam-u2f opens the marker while authenticating and closes it afterwards. The
// marker contains no data; its existence alone does NOT mean a touch is pending.
// Only a hardware U2F_ON event actually produces a notification.
func watchPAMRequests() {
	directory := os.Getenv("YUBIKEY_TOUCH_DETECTOR_PAM_DIR")
	if directory == "" {
		return
	}
	fd, err := unix.InotifyInit1(unix.IN_CLOEXEC)
	if err != nil {
		return
	}
	services := make(map[int]string)
	for _, service := range []string{"sudo", "swaylock"} {
		wd, err := unix.InotifyAddWatch(fd, filepath.Join(directory, service), unix.IN_OPEN|unix.IN_CLOSE)
		if err == nil {
			services[wd] = service
		}
	}
	if len(services) == 0 {
		unix.Close(fd)
		return
	}
	go func() {
		defer unix.Close(fd)
		buffer := make([]byte, 4096)
		for {
			n, err := unix.Read(fd, buffer)
			if err == unix.EINTR {
				continue
			}
			if err != nil {
				return
			}
			for offset := 0; offset+unix.SizeofInotifyEvent <= n; {
				wd := int(int32(binary.NativeEndian.Uint32(buffer[offset:])))
				mask := binary.NativeEndian.Uint32(buffer[offset+4:])
				length := int(binary.NativeEndian.Uint32(buffer[offset+12:]))
				offset += unix.SizeofInotifyEvent + length
				requesterState.Lock()
				if mask&unix.IN_Q_OVERFLOW != 0 {
					clear(requesterState.pam)
				} else if service := services[wd]; service != "" {
					if mask&unix.IN_OPEN != 0 {
						requesterState.pam[service]++
					} else if mask&unix.IN_CLOSE != 0 && requesterState.pam[service] > 0 {
						requesterState.pam[service]--
					}
				}
				requesterState.Unlock()
			}
		}
	}()
}
