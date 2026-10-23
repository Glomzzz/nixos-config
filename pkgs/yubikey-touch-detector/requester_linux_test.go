package notifier

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

func fakeProcess(t *testing.T, proc string, pid, parent int, name string) string {
	t.Helper()
	directory := filepath.Join(proc, fmt.Sprint(pid))
	if err := os.MkdirAll(filepath.Join(directory, "fd"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(directory, "fdinfo"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("/nix/store/test/bin/"+name, filepath.Join(directory, "exe")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(directory, "status"), []byte(fmt.Sprintf("PPid:\t%d\n", parent)), 0600); err != nil {
		t.Fatal(err)
	}
	return directory
}

func TestRequesterProcessLabels(t *testing.T) {
	proc := t.TempDir()
	fakeProcess(t, proc, 10, 1, "jj")
	fakeProcess(t, proc, 11, 10, "gpg")
	fakeProcess(t, proc, 12, 1, "bash")
	fakeProcess(t, proc, 13, 12, "gpg")
	fakeProcess(t, proc, 14, 1, ".firefox-wrapped")
	fakeProcess(t, proc, 15, 1, "bad\nname")
	for pid, expected := range map[int]string{10: "jj", 11: "jj", 13: "gpg", 14: "firefox", 15: "badname", 99: ""} {
		if actual := processLabel(proc, pid); actual != expected {
			t.Errorf("pid %d: got %q, want %q", pid, actual, expected)
		}
	}
}

func TestRequesterDeviceLabels(t *testing.T) {
	proc := t.TempDir()
	for pid, name := range map[int]string{10: ".firefox-wrapped", 11: "observer", 12: "chromium"} {
		directory := fakeProcess(t, proc, pid, 1, name)
		if err := os.Symlink("/dev/hidraw1", filepath.Join(directory, "fd/5")); err != nil {
			t.Fatal(err)
		}
		flags := "flags:\t0100002\n"
		if pid == 11 {
			flags = "flags:\t0100000\n"
		}
		if err := os.WriteFile(filepath.Join(directory, "fdinfo/5"), []byte(flags), 0600); err != nil {
			t.Fatal(err)
		}
	}
	if actual := deviceLabels(proc, map[string]bool{"/dev/hidraw1": true}); !reflect.DeepEqual(actual, []string{"chromium", "firefox"}) {
		t.Fatalf("wrong writable device holders: %v", actual)
	}
	if actual := deviceLabels(proc, map[string]bool{"/dev/hidraw2": true}); len(actual) != 0 {
		t.Fatalf("unrelated device attributed: %v", actual)
	}
}

func resetRequesters() {
	requesterState.Lock()
	defer requesterState.Unlock()
	clear(requesterState.pids)
	clear(requesterState.devices)
	clear(requesterState.pam)
}

func TestRequesterFallbacksAndPAM(t *testing.T) {
	resetRequesters()
	defer resetRequesters()
	for reason, expected := range map[string]string{
		"gpg": "OpenPGP/SSH", "u2f": "FIDO/WebAuthn", "hmac": "HMAC challenge-response",
	} {
		if actual := requesterSummary(reason); actual != expected {
			t.Errorf("%s: got %q, want %q", reason, actual, expected)
		}
	}
	requesterState.Lock()
	requesterState.pam["sudo"] = 1
	requesterState.Unlock()
	if actual := requesterSummary("u2f"); actual != "sudo" {
		t.Fatal(actual)
	}
	requesterState.Lock()
	requesterState.pam["swaylock"] = 1
	requesterState.Unlock()
	if actual := requesterSummary("u2f"); actual != "FIDO/WebAuthn" {
		t.Fatalf("ambiguous requests must not be guessed: %s", actual)
	}
	requesterState.Lock()
	clear(requesterState.pam)
	requesterState.pam["<untrusted>"] = 1
	requesterState.Unlock()
	if actual := requesterSummary("u2f"); actual != "&lt;untrusted&gt;" {
		t.Fatalf("metadata must be markup-escaped: %s", actual)
	}
	SetRequester("gpg", os.Getpid())
	if actual := requesterSummary("gpg"); actual == "OpenPGP/SSH" || actual == "" {
		t.Fatalf("live peer not identified: %s", actual)
	}
	SetRequester("gpg", 0)
	if actual := requesterSummary("gpg"); actual != "OpenPGP/SSH" {
		t.Fatalf("stale peer retained: %s", actual)
	}
}

func TestRequesterDeviceWatcherGenerations(t *testing.T) {
	resetRequesters()
	defer resetRequesters()
	SetTouchDevice(1, "/dev/hidraw1", true)
	SetTouchDevice(2, "/dev/hidraw1", true)
	SetTouchDevice(1, "/dev/hidraw1", false)
	requesterState.Lock()
	defer requesterState.Unlock()
	if requesterState.devices[2] != "/dev/hidraw1" || len(requesterState.devices) != 1 {
		t.Fatalf("old watcher cleared a new request: %v", requesterState.devices)
	}
}

func TestRequesterPAMOpenClose(t *testing.T) {
	resetRequesters()
	defer resetRequesters()
	directory := t.TempDir()
	for _, service := range []string{"sudo", "swaylock"} {
		if err := os.WriteFile(filepath.Join(directory, service), nil, 0600); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("YUBIKEY_TOUCH_DETECTOR_PAM_DIR", directory)
	watchPAMRequests()
	waitFor := func(expected string) {
		t.Helper()
		deadline := time.Now().Add(time.Second)
		for time.Now().Before(deadline) {
			if requesterSummary("u2f") == expected {
				return
			}
			time.Sleep(time.Millisecond)
		}
		t.Fatalf("expected %s, got %s", expected, requesterSummary("u2f"))
	}
	file, err := os.Open(filepath.Join(directory, "sudo"))
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	waitFor("sudo")
	file.Close()
	waitFor("FIDO/WebAuthn")
}

func TestRequesterPeerCredentials(t *testing.T) {
	listener, err := net.Listen("unix", filepath.Join(t.TempDir(), "agent"))
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	client, err := net.Dial("unix", listener.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	server, err := listener.Accept()
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()
	if actual := PeerPID(server); actual != os.Getpid() {
		t.Fatalf("got peer %d, want %d", actual, os.Getpid())
	}
}

type capturedTouchNotification struct {
	summary  string
	replaces uint32
	hints    map[string]dbus.Variant
	timeout  int32
}

type touchNotificationServer struct {
	shown  chan capturedTouchNotification
	closed chan uint32
}

func (server *touchNotificationServer) Notify(app string, replaces uint32, icon, summary, body string, actions []string, hints map[string]dbus.Variant, timeout int32) (uint32, *dbus.Error) {
	server.shown <- capturedTouchNotification{summary, replaces, hints, timeout}
	return 42, nil
}

func (server *touchNotificationServer) CloseNotification(id uint32) *dbus.Error {
	server.closed <- id
	return nil
}

func TestRequesterNotificationLifecycle(t *testing.T) {
	// The Nix check supplies a private bus; never borrow an interactive bus.
	if os.Getenv("YUBIKEY_TOUCH_TEST_PRIVATE_BUS") != "1" {
		t.Skip("requires the isolated Nix test bus")
	}
	resetRequesters()
	defer resetRequesters()
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	server := &touchNotificationServer{shown: make(chan capturedTouchNotification, 10), closed: make(chan uint32, 10)}
	if err := conn.Export(server, notificationsPath, notificationsInterface); err != nil {
		t.Fatal(err)
	}
	if _, err := conn.RequestName(notificationsInterface, dbus.NameFlagDoNotQueue); err != nil {
		t.Fatal(err)
	}
	notifiers := &sync.Map{}
	go setupLibnotifyNotifier(notifiers, "{{.Requesters}} requires a yubikey touch", "Touch only if you initiated this operation.")
	var messages chan Message
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if value, ok := notifiers.Load("notifier/libnotify"); ok {
			messages = value.(chan Message)
			break
		}
		time.Sleep(time.Millisecond)
	}
	if messages == nil {
		t.Fatal("notifier did not start")
	}
	shown := func() capturedTouchNotification {
		t.Helper()
		select {
		case notification := <-server.shown:
			return notification
		case <-time.After(3 * time.Second):
			t.Fatal("notification not received")
			return capturedTouchNotification{}
		}
	}
	messages <- U2F_ON
	first := shown()
	if first.summary != "FIDO/WebAuthn requires a yubikey touch" || first.replaces != 0 {
		t.Fatalf("unexpected initial notification: %+v", first)
	}
	if first.hints["urgency"].Value() != byte(2) || first.hints["transient"].Value() != true || first.timeout != 0 {
		t.Fatalf("touch notification must be critical, transient and persistent: %+v", first)
	}
	// Overlapping waits can change the attribution without changing the
	// aggregated U2F_ON state. Refresh must replace the popup, not leave WHO stale.
	requesterState.Lock()
	requesterState.pam["sudo"] = 1
	requesterState.Unlock()
	updated := shown()
	if updated.summary != "sudo requires a yubikey touch" || updated.replaces != 42 {
		t.Fatalf("attribution was not refreshed in place: %+v", updated)
	}
	messages <- U2F_OFF
	select {
	case id := <-server.closed:
		if id != 42 {
			t.Fatalf("closed wrong notification: %d", id)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("notification did not close after touch/cancellation")
	}
}

func TestRequesterTitleTemplate(t *testing.T) {
	resetRequesters()
	defer resetRequesters()
	templates, err := newNotificationTemplates("{{.Requesters}} requires a yubikey touch", "Touch only for an operation you initiated.")
	if err != nil {
		t.Fatal(err)
	}
	title, _, err := templates.render("u2f")
	if err != nil || !strings.HasSuffix(title, " requires a yubikey touch") || strings.Contains(title, "{{") {
		t.Fatalf("title=%q err=%v", title, err)
	}
}
