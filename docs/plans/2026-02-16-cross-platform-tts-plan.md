# Cross-Platform TTS Binary Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace Linux-only shell scripts with a cross-platform Go binary (`speak`) that handles TTS queuing, ElevenLabs API calls, MP3 decoding, and audio playback on Linux, macOS, and Windows.

**Architecture:** Single Go binary with three modes (client/daemon/stop). Client enqueues text to a file-based queue and starts a background worker daemon. The daemon reads the queue FIFO, calls ElevenLabs API for MP3 audio, decodes with go-mp3, and plays via oto v3 (CoreAudio/WASAPI/ALSA). Built natively per platform via GitHub Actions matrix.

**Tech Stack:** Go 1.22+, oto v3, go-mp3, GitHub Actions for CI/CD

**Design doc:** `docs/plans/2026-02-16-cross-platform-tts-design.md`

---

### Task 1: Initialize Go Module

**Files:**
- Create: `elevenlabs-tts/go.mod`
- Create: `elevenlabs-tts/cmd/speak/main.go` (stub)

**Step 1: Initialize go module**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go mod init github.com/dkmaker/my-claude-plugins/elevenlabs-tts
```

**Step 2: Create minimal main.go stub**

Create `elevenlabs-tts/cmd/speak/main.go`:
```go
package main

import (
	"fmt"
	"os"
)

// Version is set at build time via ldflags
var Version = "dev"

func main() {
	if len(os.Args) > 1 && os.Args[1] == "--version" {
		fmt.Println(Version)
		os.Exit(0)
	}
	fmt.Fprintln(os.Stderr, "speak: not yet implemented")
	os.Exit(1)
}
```

**Step 3: Verify it builds**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go build -o speak ./cmd/speak/
./speak --version
```

Expected: prints `dev`

**Step 4: Commit**

```bash
git add elevenlabs-tts/go.mod elevenlabs-tts/cmd/speak/main.go
git commit -m "feat(elevenlabs-tts): initialize Go module with speak binary stub"
```

---

### Task 2: Implement Queue Package

**Files:**
- Create: `elevenlabs-tts/internal/queue/queue.go`
- Create: `elevenlabs-tts/internal/queue/queue_test.go`

**Step 1: Write the failing test**

Create `elevenlabs-tts/internal/queue/queue_test.go`:
```go
package queue_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/queue"
)

func TestEnqueueAndDequeue(t *testing.T) {
	dir := t.TempDir()
	q := queue.New(dir)

	// Enqueue two messages
	if err := q.Enqueue("hello"); err != nil {
		t.Fatalf("Enqueue: %v", err)
	}
	if err := q.Enqueue("world"); err != nil {
		t.Fatalf("Enqueue: %v", err)
	}

	// Dequeue should return FIFO order
	msg, ok, err := q.Dequeue()
	if err != nil {
		t.Fatalf("Dequeue: %v", err)
	}
	if !ok || msg != "hello" {
		t.Errorf("got %q, want %q", msg, "hello")
	}

	msg, ok, err = q.Dequeue()
	if err != nil {
		t.Fatalf("Dequeue: %v", err)
	}
	if !ok || msg != "world" {
		t.Errorf("got %q, want %q", msg, "world")
	}

	// Empty queue
	_, ok, err = q.Dequeue()
	if err != nil {
		t.Fatalf("Dequeue: %v", err)
	}
	if ok {
		t.Error("expected empty queue")
	}
}

func TestQueueFileCreation(t *testing.T) {
	dir := t.TempDir()
	q := queue.New(dir)
	if err := q.Enqueue("test"); err != nil {
		t.Fatalf("Enqueue: %v", err)
	}
	queueFile := filepath.Join(dir, "queue")
	if _, err := os.Stat(queueFile); os.IsNotExist(err) {
		t.Error("queue file should exist after enqueue")
	}
}
```

**Step 2: Run test to verify it fails**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go test ./internal/queue/ -v
```

Expected: compilation error — package doesn't exist yet.

**Step 3: Implement queue package**

Create `elevenlabs-tts/internal/queue/queue.go`:
```go
package queue

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Queue manages a file-based FIFO message queue with file locking.
type Queue struct {
	dir      string
	filePath string
	lockPath string
}

// New creates a Queue that stores messages in the given directory.
func New(dir string) *Queue {
	return &Queue{
		dir:      dir,
		filePath: filepath.Join(dir, "queue"),
		lockPath: filepath.Join(dir, "queue.lock"),
	}
}

// Dir returns the queue directory path.
func (q *Queue) Dir() string {
	return q.dir
}

// Enqueue appends a message to the queue file atomically.
func (q *Queue) Enqueue(message string) error {
	if err := os.MkdirAll(q.dir, 0755); err != nil {
		return fmt.Errorf("create queue dir: %w", err)
	}

	unlock, err := q.lock()
	if err != nil {
		return fmt.Errorf("lock queue: %w", err)
	}
	defer unlock()

	f, err := os.OpenFile(q.filePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("open queue: %w", err)
	}
	defer f.Close()

	if _, err := fmt.Fprintln(f, message); err != nil {
		return fmt.Errorf("write queue: %w", err)
	}
	return nil
}

// Dequeue reads and removes the first message from the queue.
// Returns ("", false, nil) if queue is empty.
func (q *Queue) Dequeue() (string, bool, error) {
	unlock, err := q.lock()
	if err != nil {
		return "", false, fmt.Errorf("lock queue: %w", err)
	}
	defer unlock()

	f, err := os.Open(q.filePath)
	if os.IsNotExist(err) {
		return "", false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("open queue: %w", err)
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	if !scanner.Scan() {
		return "", false, nil
	}
	first := scanner.Text()

	// Read remaining lines
	var remaining []string
	for scanner.Scan() {
		remaining = append(remaining, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		return "", false, fmt.Errorf("read queue: %w", err)
	}
	f.Close()

	// Rewrite queue without first line
	if len(remaining) == 0 {
		os.Remove(q.filePath)
	} else {
		if err := os.WriteFile(q.filePath, []byte(strings.Join(remaining, "\n")+"\n"), 0644); err != nil {
			return "", false, fmt.Errorf("rewrite queue: %w", err)
		}
	}

	return first, true, nil
}
```

**Step 4: Create platform-specific lock files**

Create `elevenlabs-tts/internal/queue/lock_unix.go`:
```go
//go:build !windows

package queue

import (
	"fmt"
	"os"
	"syscall"
)

func (q *Queue) lock() (unlock func(), err error) {
	f, err := os.OpenFile(q.lockPath, os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return nil, fmt.Errorf("open lock file: %w", err)
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		f.Close()
		return nil, fmt.Errorf("flock: %w", err)
	}
	return func() {
		syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
		f.Close()
	}, nil
}
```

Create `elevenlabs-tts/internal/queue/lock_windows.go`:
```go
//go:build windows

package queue

import (
	"fmt"
	"os"
	"syscall"
	"unsafe"
)

var (
	modkernel32    = syscall.NewLazyDLL("kernel32.dll")
	procLockFileEx = modkernel32.NewProc("LockFileEx")
	procUnlockFile = modkernel32.NewProc("UnlockFile")
)

const lockfileExclusiveLock = 0x00000002

func (q *Queue) lock() (unlock func(), err error) {
	f, err := os.OpenFile(q.lockPath, os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return nil, fmt.Errorf("open lock file: %w", err)
	}

	// LockFileEx(handle, flags, reserved, nNumberOfBytesToLockLow, nNumberOfBytesToLockHigh, overlapped)
	ol := new(syscall.Overlapped)
	r, _, e := procLockFileEx.Call(
		f.Fd(),
		lockfileExclusiveLock,
		0,
		1, 0,
		uintptr(unsafe.Pointer(ol)),
	)
	if r == 0 {
		f.Close()
		return nil, fmt.Errorf("LockFileEx: %w", e)
	}

	return func() {
		procUnlockFile.Call(f.Fd(), 0, 0, 1, 0)
		f.Close()
	}, nil
}
```

**Step 5: Run tests**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go test ./internal/queue/ -v
```

Expected: all tests PASS.

**Step 6: Commit**

```bash
git add elevenlabs-tts/internal/queue/
git commit -m "feat(elevenlabs-tts): add cross-platform file-based queue with locking"
```

---

### Task 3: Implement ElevenLabs API Client

**Files:**
- Create: `elevenlabs-tts/internal/elevenlabs/client.go`
- Create: `elevenlabs-tts/internal/elevenlabs/client_test.go`

**Step 1: Write the failing test**

Create `elevenlabs-tts/internal/elevenlabs/client_test.go`:
```go
package elevenlabs_test

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/elevenlabs"
)

func TestSynthesize(t *testing.T) {
	fakeMP3 := []byte("fake-mp3-data")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify request
		if r.Method != "POST" {
			t.Errorf("expected POST, got %s", r.Method)
		}
		if !strings.Contains(r.URL.Path, "/v1/text-to-speech/") {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
		if r.Header.Get("xi-api-key") != "test-key" {
			t.Errorf("missing or wrong API key")
		}

		body, _ := io.ReadAll(r.Body)
		if !strings.Contains(string(body), "hello world") {
			t.Errorf("body missing text: %s", body)
		}

		w.Header().Set("Content-Type", "audio/mpeg")
		w.Write(fakeMP3)
	}))
	defer server.Close()

	client := elevenlabs.NewClient("test-key",
		elevenlabs.WithBaseURL(server.URL),
		elevenlabs.WithVoiceID("test-voice"),
		elevenlabs.WithModel("test-model"),
	)

	data, err := client.Synthesize("hello world")
	if err != nil {
		t.Fatalf("Synthesize: %v", err)
	}
	if string(data) != string(fakeMP3) {
		t.Errorf("got %q, want %q", data, fakeMP3)
	}
}

func TestSynthesizeNoAPIKey(t *testing.T) {
	client := elevenlabs.NewClient("")
	_, err := client.Synthesize("test")
	if err == nil {
		t.Error("expected error for empty API key")
	}
}
```

**Step 2: Run test to verify it fails**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go test ./internal/elevenlabs/ -v
```

Expected: compilation error.

**Step 3: Implement client**

Create `elevenlabs-tts/internal/elevenlabs/client.go`:
```go
package elevenlabs

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const (
	defaultBaseURL = "https://api.elevenlabs.io"
	defaultVoiceID = "21m00Tcm4TlvDq8ikWAM" // Rachel
	defaultModel   = "eleven_flash_v2_5"
)

// Client calls the ElevenLabs text-to-speech API.
type Client struct {
	apiKey  string
	baseURL string
	voiceID string
	model   string
	http    *http.Client
}

// Option configures a Client.
type Option func(*Client)

func WithBaseURL(url string) Option  { return func(c *Client) { c.baseURL = url } }
func WithVoiceID(id string) Option   { return func(c *Client) { c.voiceID = id } }
func WithModel(model string) Option  { return func(c *Client) { c.model = model } }

// NewClient creates an ElevenLabs API client.
func NewClient(apiKey string, opts ...Option) *Client {
	c := &Client{
		apiKey:  apiKey,
		baseURL: defaultBaseURL,
		voiceID: defaultVoiceID,
		model:   defaultModel,
		http:    &http.Client{Timeout: 15 * time.Second},
	}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

type synthesizeRequest struct {
	Text    string `json:"text"`
	ModelID string `json:"model_id"`
}

// Synthesize sends text to ElevenLabs and returns the MP3 audio bytes.
func (c *Client) Synthesize(text string) ([]byte, error) {
	if c.apiKey == "" {
		return nil, fmt.Errorf("ELEVENLABS_API_KEY not set")
	}

	body, err := json.Marshal(synthesizeRequest{Text: text, ModelID: c.model})
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/v1/text-to-speech/%s", c.baseURL, c.voiceID)
	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("xi-api-key", c.apiKey)

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("API request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		errBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API error %d: %s", resp.StatusCode, string(errBody))
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}
	return data, nil
}
```

**Step 4: Run tests**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go test ./internal/elevenlabs/ -v
```

Expected: all tests PASS.

**Step 5: Commit**

```bash
git add elevenlabs-tts/internal/elevenlabs/
git commit -m "feat(elevenlabs-tts): add ElevenLabs API client with tests"
```

---

### Task 4: Implement Audio Player

**Files:**
- Create: `elevenlabs-tts/internal/audio/player.go`
- Create: `elevenlabs-tts/internal/audio/player_test.go`

**Step 1: Add oto and go-mp3 dependencies**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go get github.com/ebitengine/oto/v3
go get github.com/hajimehoshi/go-mp3
```

**Step 2: Write the test**

Create `elevenlabs-tts/internal/audio/player_test.go`:
```go
package audio_test

import (
	"testing"

	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/audio"
)

func TestNewPlayer(t *testing.T) {
	// Test that we can create and close a player
	p, err := audio.NewPlayer()
	if err != nil {
		t.Fatalf("NewPlayer: %v", err)
	}
	p.Close()
}

func TestPlayInvalidMP3(t *testing.T) {
	p, err := audio.NewPlayer()
	if err != nil {
		t.Fatalf("NewPlayer: %v", err)
	}
	defer p.Close()

	err = p.PlayMP3([]byte("not valid mp3 data"))
	if err == nil {
		t.Error("expected error for invalid MP3 data")
	}
}
```

Note: Testing actual audio playback requires a real audio device. These tests verify construction and error handling. Manual testing needed for actual playback on each platform.

**Step 3: Implement audio player**

Create `elevenlabs-tts/internal/audio/player.go`:
```go
package audio

import (
	"bytes"
	"fmt"
	"io"
	"time"

	"github.com/ebitengine/oto/v3"
	"github.com/hajimehoshi/go-mp3"
)

// Player manages audio playback using oto.
type Player struct {
	ctx *oto.Context
}

// NewPlayer creates an audio player. Call Close when done.
func NewPlayer() (*Player, error) {
	// go-mp3 always outputs: 16-bit signed LE, stereo (2 channels)
	// Sample rate varies per MP3 but 44100 is most common.
	// We'll create context on first play to match the actual sample rate.
	return &Player{}, nil
}

// ensureContext creates or reuses the oto context for the given sample rate.
func (p *Player) ensureContext(sampleRate int) error {
	if p.ctx != nil {
		return nil
	}
	ctx, ready, err := oto.NewContext(&oto.NewContextOptions{
		SampleRate:   sampleRate,
		ChannelCount: 2, // go-mp3 always outputs stereo
		Format:       oto.FormatSignedInt16LE,
	})
	if err != nil {
		return fmt.Errorf("create audio context: %w", err)
	}
	<-ready
	p.ctx = ctx
	return nil
}

// PlayMP3 decodes MP3 data and plays it synchronously. Returns when playback is complete.
func (p *Player) PlayMP3(data []byte) error {
	decoder, err := mp3.NewDecoder(bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("decode mp3: %w", err)
	}

	if err := p.ensureContext(decoder.SampleRate()); err != nil {
		return err
	}

	player := p.ctx.NewPlayer(decoder)
	defer player.Close()

	// Play all audio
	if _, err := io.Copy(player, decoder); err != nil {
		return fmt.Errorf("play audio: %w", err)
	}

	// Wait for buffer to drain
	for player.IsPlaying() {
		time.Sleep(10 * time.Millisecond)
	}

	return nil
}

// Close releases audio resources.
func (p *Player) Close() {
	// oto.Context doesn't have a Close method — it lives for the process lifetime.
	// This is fine because the worker daemon owns the player.
}
```

**Step 4: Run tests**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go test ./internal/audio/ -v
```

Expected: NewPlayer passes. PlayInvalidMP3 returns error. (Note: on headless CI without audio device, oto may fail to initialize — that's expected and tests should be tagged appropriately if needed.)

**Step 5: Commit**

```bash
git add elevenlabs-tts/internal/audio/ elevenlabs-tts/go.mod elevenlabs-tts/go.sum
git commit -m "feat(elevenlabs-tts): add cross-platform audio player using oto v3"
```

---

### Task 5: Implement Worker Daemon

**Files:**
- Create: `elevenlabs-tts/internal/worker/worker.go`
- Create: `elevenlabs-tts/internal/worker/worker_test.go`

**Step 1: Write the failing test**

Create `elevenlabs-tts/internal/worker/worker_test.go`:
```go
package worker_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/queue"
	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/worker"
)

func TestWorkerWritesPID(t *testing.T) {
	dir := t.TempDir()
	q := queue.New(dir)

	w := worker.New(q, nil, worker.WithIdleTimeout(1*time.Second))
	go w.Run()
	defer w.Stop()

	time.Sleep(100 * time.Millisecond)

	pidFile := filepath.Join(dir, "worker.pid")
	if _, err := os.Stat(pidFile); os.IsNotExist(err) {
		t.Error("worker.pid should exist while worker is running")
	}
}

func TestWorkerIdleTimeout(t *testing.T) {
	dir := t.TempDir()
	q := queue.New(dir)

	w := worker.New(q, nil, worker.WithIdleTimeout(500*time.Millisecond))

	done := make(chan struct{})
	go func() {
		w.Run()
		close(done)
	}()

	select {
	case <-done:
		// Worker exited due to idle timeout — good
	case <-time.After(3 * time.Second):
		t.Error("worker did not exit after idle timeout")
		w.Stop()
	}
}
```

**Step 2: Run test to verify it fails**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go test ./internal/worker/ -v
```

Expected: compilation error.

**Step 3: Implement worker**

Create `elevenlabs-tts/internal/worker/worker.go`:
```go
package worker

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/queue"
)

const defaultIdleTimeout = 60 * time.Second

// SpeakFunc processes a text message (calls API + plays audio).
type SpeakFunc func(text string) error

// Worker is the background TTS daemon that reads from a queue and speaks.
type Worker struct {
	queue       *queue.Queue
	speak       SpeakFunc
	idleTimeout time.Duration
	stopCh      chan struct{}
}

// Option configures a Worker.
type Option func(*Worker)

func WithIdleTimeout(d time.Duration) Option {
	return func(w *Worker) { w.idleTimeout = d }
}

// New creates a Worker. speakFn can be nil for testing (messages are discarded).
func New(q *queue.Queue, speakFn SpeakFunc, opts ...Option) *Worker {
	w := &Worker{
		queue:       q,
		speak:       speakFn,
		idleTimeout: defaultIdleTimeout,
		stopCh:      make(chan struct{}),
	}
	for _, opt := range opts {
		opt(w)
	}
	return w
}

// Run starts the worker loop. Blocks until idle timeout or Stop is called.
func (w *Worker) Run() {
	// Write PID file
	pidPath := filepath.Join(w.queue.Dir(), "worker.pid")
	os.WriteFile(pidPath, []byte(strconv.Itoa(os.Getpid())), 0644)
	defer os.Remove(pidPath)

	idleStart := time.Now()

	for {
		select {
		case <-w.stopCh:
			return
		default:
		}

		msg, ok, err := w.queue.Dequeue()
		if err != nil {
			log.Printf("queue error: %v", err)
			time.Sleep(500 * time.Millisecond)
			continue
		}

		if !ok {
			// Queue empty — check idle timeout
			if time.Since(idleStart) >= w.idleTimeout {
				return
			}
			time.Sleep(250 * time.Millisecond)
			continue
		}

		// Reset idle timer
		idleStart = time.Now()

		if w.speak != nil {
			if err := w.speak(msg); err != nil {
				log.Printf("speak error: %v", err)
			}
		}
	}
}

// Stop signals the worker to exit.
func (w *Worker) Stop() {
	select {
	case <-w.stopCh:
	default:
		close(w.stopCh)
	}
}

// IsRunning checks if a worker process is running by reading the PID file.
func IsRunning(dir string) (int, bool) {
	pidPath := filepath.Join(dir, "worker.pid")
	data, err := os.ReadFile(pidPath)
	if err != nil {
		return 0, false
	}
	pid, err := strconv.Atoi(string(data))
	if err != nil {
		return 0, false
	}
	// Check if process exists
	proc, err := os.FindProcess(pid)
	if err != nil {
		return 0, false
	}
	// On Unix, FindProcess always succeeds. Send signal 0 to check.
	err = proc.Signal(os.Signal(nil))
	if err != nil {
		return 0, false
	}
	return pid, true
}

// StopByPID reads the PID file and kills the worker process.
func StopByPID(dir string) error {
	pid, running := IsRunning(dir)
	if !running {
		return nil
	}
	proc, err := os.FindProcess(pid)
	if err != nil {
		return fmt.Errorf("find process %d: %w", pid, err)
	}
	return proc.Kill()
}
```

**Step 4: Run tests**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go test ./internal/worker/ -v -timeout 10s
```

Expected: both tests PASS.

**Step 5: Commit**

```bash
git add elevenlabs-tts/internal/worker/
git commit -m "feat(elevenlabs-tts): add worker daemon with idle timeout and PID management"
```

---

### Task 6: Wire Up CLI (main.go)

**Files:**
- Modify: `elevenlabs-tts/cmd/speak/main.go`

**Step 1: Implement the full CLI**

Replace `elevenlabs-tts/cmd/speak/main.go` with:
```go
package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/audio"
	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/elevenlabs"
	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/queue"
	"github.com/dkmaker/my-claude-plugins/elevenlabs-tts/internal/worker"
)

var Version = "dev"

func main() {
	log.SetFlags(0)
	log.SetPrefix("speak: ")

	if len(os.Args) < 2 {
		os.Exit(0) // No args, no-op (matches current speak.sh behavior)
	}

	ttsDir := filepath.Join(homeDir(), ".claude", "tts")
	os.MkdirAll(ttsDir, 0755)

	switch os.Args[1] {
	case "--version":
		fmt.Println(Version)
	case "--daemon":
		runDaemon(ttsDir)
	case "--stop":
		if err := worker.StopByPID(ttsDir); err != nil {
			log.Fatalf("stop worker: %v", err)
		}
	default:
		// Client mode: enqueue message and ensure daemon is running
		message := strings.Join(os.Args[1:], " ")
		enqueueAndEnsureDaemon(ttsDir, message)
	}
}

func enqueueAndEnsureDaemon(ttsDir, message string) {
	q := queue.New(ttsDir)
	if err := q.Enqueue(message); err != nil {
		log.Fatalf("enqueue: %v", err)
	}

	// Start daemon if not running
	if _, running := worker.IsRunning(ttsDir); !running {
		exe, err := os.Executable()
		if err != nil {
			log.Fatalf("find executable: %v", err)
		}
		cmd := exec.Command(exe, "--daemon")
		cmd.Stdout = nil
		cmd.Stderr = nil
		// Detach from parent process
		detachProcess(cmd)
		if err := cmd.Start(); err != nil {
			log.Fatalf("start daemon: %v", err)
		}
		// Don't wait — daemon runs in background
	}
}

func runDaemon(ttsDir string) {
	apiKey := os.Getenv("ELEVENLABS_API_KEY")
	if apiKey == "" {
		log.Fatal("ELEVENLABS_API_KEY not set")
	}

	// Create API client
	opts := []elevenlabs.Option{}
	if v := os.Getenv("ELEVENLABS_VOICE_ID"); v != "" {
		opts = append(opts, elevenlabs.WithVoiceID(v))
	}
	if m := os.Getenv("ELEVENLABS_MODEL"); m != "" {
		opts = append(opts, elevenlabs.WithModel(m))
	}
	client := elevenlabs.NewClient(apiKey, opts...)

	// Create audio player
	player, err := audio.NewPlayer()
	if err != nil {
		log.Fatalf("create audio player: %v", err)
	}
	defer player.Close()

	// Create speak function
	speakFn := func(text string) error {
		data, err := client.Synthesize(text)
		if err != nil {
			return fmt.Errorf("synthesize: %w", err)
		}
		if err := player.PlayMP3(data); err != nil {
			return fmt.Errorf("play: %w", err)
		}
		return nil
	}

	// Run worker
	q := queue.New(ttsDir)
	w := worker.New(q, speakFn)
	w.Run()
}

func homeDir() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	if h := os.Getenv("USERPROFILE"); h != "" {
		return h
	}
	if runtime.GOOS == "windows" {
		return os.Getenv("HOMEDRIVE") + os.Getenv("HOMEPATH")
	}
	return "/"
}
```

**Step 2: Create platform-specific process detach files**

Create `elevenlabs-tts/cmd/speak/detach_unix.go`:
```go
//go:build !windows

package main

import (
	"os/exec"
	"syscall"
)

func detachProcess(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{
		Setsid: true,
	}
}
```

Create `elevenlabs-tts/cmd/speak/detach_windows.go`:
```go
//go:build windows

package main

import (
	"os/exec"
	"syscall"
)

func detachProcess(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: syscall.CREATE_NEW_PROCESS_GROUP,
	}
}
```

**Step 3: Verify it builds**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
go build -ldflags "-X main.Version=1.1.0" -o speak ./cmd/speak/
./speak --version
```

Expected: prints `1.1.0`

**Step 4: Commit**

```bash
git add elevenlabs-tts/cmd/speak/
git commit -m "feat(elevenlabs-tts): wire up CLI with client, daemon, and stop modes"
```

---

### Task 7: Add Makefile

**Files:**
- Create: `elevenlabs-tts/Makefile`

**Step 1: Create Makefile**

Create `elevenlabs-tts/Makefile`:
```makefile
VERSION ?= dev
BINARY_NAME = speak
LDFLAGS = -ldflags "-s -w -X main.Version=$(VERSION)"

.PHONY: build clean test

build:
	go build $(LDFLAGS) -o $(BINARY_NAME) ./cmd/speak/

test:
	go test ./... -v -timeout 30s

clean:
	rm -f $(BINARY_NAME)
	rm -f speak-*

# Native build for current platform (used by CI)
build-native:
	go build $(LDFLAGS) -o $(BINARY_NAME)-$(shell go env GOOS)-$(shell go env GOARCH)$(shell go env GOEXE) ./cmd/speak/
```

**Step 2: Verify**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
make build VERSION=1.1.0
./speak --version
```

Expected: prints `1.1.0`

**Step 3: Commit**

```bash
git add elevenlabs-tts/Makefile
git commit -m "chore(elevenlabs-tts): add Makefile for build and test"
```

---

### Task 8: Add GitHub Actions Release Workflow

**Files:**
- Create: `.github/workflows/release-speak.yml`

**Step 1: Create the workflow**

Create `.github/workflows/release-speak.yml`:
```yaml
name: Release speak binary

on:
  push:
    tags:
      - 'speak-v*'

permissions:
  contents: write

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            goos: linux
            goarch: amd64
          - os: macos-latest
            goos: darwin
            goarch: amd64
          - os: macos-latest
            goos: darwin
            goarch: arm64
          - os: windows-latest
            goos: windows
            goarch: amd64
    runs-on: ${{ matrix.os }}
    defaults:
      run:
        working-directory: elevenlabs-tts
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Extract version from tag
        id: version
        shell: bash
        run: echo "version=${GITHUB_REF_NAME#speak-v}" >> "$GITHUB_OUTPUT"

      - name: Build
        shell: bash
        env:
          GOOS: ${{ matrix.goos }}
          GOARCH: ${{ matrix.goarch }}
          CGO_ENABLED: '1'
        run: |
          ext=""
          if [ "${{ matrix.goos }}" = "windows" ]; then ext=".exe"; fi
          go build -ldflags "-s -w -X main.Version=${{ steps.version.outputs.version }}" \
            -o "speak-${{ matrix.goos }}-${{ matrix.goarch }}${ext}" \
            ./cmd/speak/

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: speak-${{ matrix.goos }}-${{ matrix.goarch }}
          path: elevenlabs-tts/speak-*

  release:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts
          merge-multiple: true

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: artifacts/*
          generate_release_notes: true
```

**Step 2: Commit**

```bash
git add .github/workflows/release-speak.yml
git commit -m "ci(elevenlabs-tts): add GitHub Actions release workflow for speak binary"
```

---

### Task 9: Update SessionStart Hook

**Files:**
- Modify: `elevenlabs-tts/hooks/scripts/sessionstart.sh`

**Step 1: Rewrite sessionstart.sh**

Replace the entire file with a new version that downloads the binary instead of copying shell scripts. The hook must:

1. Detect OS (`uname -s` → linux/darwin) and arch (`uname -m` → amd64/arm64)
2. Handle Windows (detect via `OSTYPE` or absence of `uname`)
3. Check if `~/.claude/tts/speak` exists and matches expected version
4. Download from GitHub Releases if needed (using curl)
5. Create symlink to `~/.local/bin/speak`
6. Kill stale worker
7. Output hook JSON

New `elevenlabs-tts/hooks/scripts/sessionstart.sh`:
```bash
#!/bin/bash
# SessionStart hook for elevenlabs-tts plugin
# Downloads the speak binary and ensures it's in PATH

REPO="dkmaker/my-claude-plugins"
TTS_DIR="$HOME/.claude/tts"
PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION_FILE="$PLUGIN_DIR/.claude-plugin/plugin.json"

# Read expected version from plugin.json
EXPECTED_VERSION=$(grep -o '"version": *"[^"]*"' "$VERSION_FILE" | head -1 | grep -o '[0-9][^"]*')

# Detect platform
detect_platform() {
    local os arch
    case "$(uname -s 2>/dev/null)" in
        Linux*)  os="linux" ;;
        Darwin*) os="darwin" ;;
        MINGW*|MSYS*|CYGWIN*) os="windows" ;;
        *)
            if [ -n "$WINDIR" ]; then
                os="windows"
            else
                os="linux"  # fallback
            fi
            ;;
    esac

    case "$(uname -m 2>/dev/null)" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) arch="amd64" ;;  # fallback
    esac

    echo "${os}-${arch}"
}

PLATFORM=$(detect_platform)
BINARY_NAME="speak"
if [[ "$PLATFORM" == windows-* ]]; then
    BINARY_NAME="speak.exe"
fi

BINARY_PATH="$TTS_DIR/$BINARY_NAME"

# Create directories
mkdir -p "$TTS_DIR" "$HOME/.local/bin"

# Check if we need to download
need_download=false
if [ ! -f "$BINARY_PATH" ]; then
    need_download=true
elif [ -n "$EXPECTED_VERSION" ]; then
    current_version=$("$BINARY_PATH" --version 2>/dev/null)
    if [ "$current_version" != "$EXPECTED_VERSION" ]; then
        need_download=true
    fi
fi

# Download if needed
if [ "$need_download" = true ] && [ -n "$EXPECTED_VERSION" ]; then
    download_url="https://github.com/${REPO}/releases/download/speak-v${EXPECTED_VERSION}/speak-${PLATFORM}"
    if [[ "$PLATFORM" == windows-* ]]; then
        download_url="${download_url}.exe"
    fi

    if curl -fsSL --connect-timeout 10 "$download_url" -o "$BINARY_PATH.tmp" 2>/dev/null; then
        mv "$BINARY_PATH.tmp" "$BINARY_PATH"
        chmod +x "$BINARY_PATH"
    else
        rm -f "$BINARY_PATH.tmp"
        # Download failed — try to continue with existing binary if any
    fi
fi

# Create symlink in PATH
if [[ "$PLATFORM" != windows-* ]]; then
    ln -sf "$BINARY_PATH" "$HOME/.local/bin/speak"
fi

# Kill stale worker so it restarts with current env
if [ -f "$TTS_DIR/worker.pid" ]; then
    pid=$(cat "$TTS_DIR/worker.pid")
    kill "$pid" 2>/dev/null
    rm -f "$TTS_DIR/worker.pid"
fi

# Determine status
if [ -f "$BINARY_PATH" ] && [ -n "$ELEVENLABS_API_KEY" ]; then
    version=$("$BINARY_PATH" --version 2>/dev/null || echo "unknown")
    status="Voice feedback ready (ElevenLabs, speak v${version})"
elif [ -f "$BINARY_PATH" ]; then
    status="Voice feedback: speak binary installed but ELEVENLABS_API_KEY not set"
else
    status="Voice feedback: Failed to download speak binary. Check https://github.com/${REPO}/releases"
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ""
  },
  "systemMessage": "$status"
}
EOF
```

**Step 2: Test hook output locally**

```bash
chmod +x /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts/hooks/scripts/sessionstart.sh
CLAUDE_PLUGIN_ROOT=/home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts \
  /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts/hooks/scripts/sessionstart.sh
```

Expected: valid JSON output with status message.

**Step 3: Commit**

```bash
git add elevenlabs-tts/hooks/scripts/sessionstart.sh
git commit -m "feat(elevenlabs-tts): update sessionstart hook to download speak binary"
```

---

### Task 10: Update Plugin Metadata and Clean Up

**Files:**
- Modify: `elevenlabs-tts/.claude-plugin/plugin.json`
- Delete: `elevenlabs-tts/scripts/speak.sh`
- Delete: `elevenlabs-tts/scripts/tts-worker.sh`
- Delete: `elevenlabs-tts/scripts/setup-piper.sh`

**Step 1: Update plugin.json**

Change version to `2.0.0` and update description:
```json
{
  "name": "elevenlabs-tts",
  "description": "Cross-platform voice feedback while coding. Claude speaks progress updates aloud via ElevenLabs API.",
  "version": "2.0.0",
  "author": {
    "name": "Christian Pedersen"
  },
  "repository": "https://github.com/dkmaker/my-claude-plugins",
  "license": "MIT",
  "keywords": ["tts", "voice", "elevenlabs", "audio", "feedback", "accessibility", "cross-platform"],
  "outputStyles": "./output-styles/"
}
```

**Step 2: Remove old shell scripts**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins
git rm elevenlabs-tts/scripts/speak.sh
git rm elevenlabs-tts/scripts/tts-worker.sh
git rm elevenlabs-tts/scripts/setup-piper.sh
rmdir elevenlabs-tts/scripts 2>/dev/null || true
```

**Step 3: Commit**

```bash
git add elevenlabs-tts/.claude-plugin/plugin.json
git commit -m "feat(elevenlabs-tts): bump to v2.0.0, remove old shell scripts

BREAKING: Removes Piper TTS local fallback. Now requires ELEVENLABS_API_KEY.
Cross-platform support: Linux, macOS, and Windows."
```

---

### Task 11: Integration Test (Manual)

**Step 1: Build and test locally**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
make build VERSION=2.0.0
cp speak ~/.claude/tts/speak
chmod +x ~/.claude/tts/speak
```

**Step 2: Test speak command**

```bash
export ELEVENLABS_API_KEY="your-key-here"
~/.claude/tts/speak "Hello, this is a cross-platform test"
```

Expected: hear audio playback after a brief API delay.

**Step 3: Test worker lifecycle**

```bash
# Should see worker.pid appear
ls -la ~/.claude/tts/worker.pid

# Stop worker
~/.claude/tts/speak --stop

# Verify PID file removed
ls -la ~/.claude/tts/worker.pid
```

**Step 4: Run all Go tests**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins/elevenlabs-tts
make test
```

Expected: all tests pass.

---

### Task 12: Tag and Release

**Step 1: Create release tag**

```bash
cd /home/cp/code/dkmaker/my-claude-plugins
git tag speak-v2.0.0
git push origin speak-v2.0.0
```

This triggers the GitHub Actions workflow to build and release binaries for all platforms.

**Step 2: Verify release**

Check https://github.com/dkmaker/my-claude-plugins/releases for the new release with binaries:
- `speak-linux-amd64`
- `speak-darwin-amd64`
- `speak-darwin-arm64`
- `speak-windows-amd64.exe`
