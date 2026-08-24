package main

import (
	"archive/zip"
	"bufio"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"math"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

// Counts bytes without keeping them, so multi-gigabyte cases cost nothing.
type countingWriter struct {
	n int64
}

func (c *countingWriter) Write(p []byte) (int, error) {
	c.n += int64(len(p))

	return len(p), nil
}

// Fixed so the arithmetic is reproducible, non-zero because zipSize counts the
// extra field a set Modified produces.
var fixedModTime = time.Date(2018, time.May, 10, 17, 17, 52, 0, time.UTC)

// Member bodies without allocating them.
type zeros struct {
	left int64
}

func (z *zeros) Read(p []byte) (int, error) {
	if z.left <= 0 {
		return 0, io.EOF
	}

	n := min(int64(len(p)), z.left)

	clear(p[:n])
	z.left -= n

	return int(n), nil
}

// Reuses storedHeader, so a change to the header shape shows up as a mismatch
// rather than passing silently.
func writeArchive(t *testing.T, members []member) int64 {
	t.Helper()

	counter := &countingWriter{}
	archive := zip.NewWriter(counter)

	for _, m := range members {
		w, err := archive.CreateHeader(storedHeader(m))
		if err != nil {
			t.Fatalf("CreateHeader(%q): %s", m.name, err)
		}

		_, err = io.Copy(w, &zeros{left: m.size})
		if err != nil {
			t.Fatalf("writing %q: %s", m.name, err)
		}
	}

	err := archive.Close()
	if err != nil {
		t.Fatalf("closing archive: %s", err)
	}

	return counter.n
}

func members(sizes ...int64) []member {
	out := make([]member, 0, len(sizes))

	for i, size := range sizes {
		out = append(out, member{
			name:    fmt.Sprintf("photo_%04d.jpg", i),
			size:    size,
			modTime: fixedModTime,
		})
	}

	return out
}

func repeatMembers(count int, size int64) []member {
	out := make([]member, 0, count)

	for i := range count {
		out = append(out, member{
			name:    fmt.Sprintf("photo_%06d.jpg", i),
			size:    size,
			modTime: fixedModTime,
		})
	}

	return out
}

// Load-bearing: Content-Length ships before the first byte, so wrong
// arithmetic means every download truncates or hangs. It rests on stdlib
// behaviour a Go release could change, and this is what would notice.
func TestZipSize(t *testing.T) {
	tests := []struct {
		name    string
		members []member
	}{
		{
			name:    "empty archive",
			members: nil,
		},
		{
			name:    "single empty file",
			members: members(0),
		},
		{
			name:    "one file",
			members: members(42653),
		},
		{
			name:    "several files",
			members: members(40632, 42653, 1, 0, 999999),
		},
		{
			name: "non-ASCII name sets the UTF-8 flag without changing the length",
			members: []member{
				{name: "Midtøsten/vår-2018.jpg", size: 1234, modTime: fixedModTime},
				{name: "Tel Aviv (2).jpg", size: 5678, modTime: fixedModTime},
			},
		},
		{
			// The end record's entry count is a uint16.
			name:    "65534 entries",
			members: repeatMembers(65534, 1),
		},
		{
			name:    "65535 entries",
			members: repeatMembers(65535, 1),
		},
		{
			name:    "65536 entries",
			members: repeatMembers(65536, 1),
		},
		{
			// Compared with >=, so uint32max itself is already zip64.
			name:    "largest non-zip64 file",
			members: members(math.MaxUint32 - 1),
		},
		{
			name:    "file at the zip64 threshold",
			members: members(math.MaxUint32),
		},
		{
			// Tiny file, but its recorded offset is past the 32-bit limit.
			name:    "small file pushed past the offset limit by a large one",
			members: members(math.MaxUint32, 17),
		},
		{
			// archive/zip omits the extended-timestamp extra when Modified is
			// zero, which would leave the body 18 bytes short of the declared
			// Content-Length. storedHeader substitutes an epoch to stop that.
			name:    "member with no mtime",
			members: []member{{name: "a.jpg", size: 100}},
		},
		{
			name: "mtimes outside the MS-DOS range",
			members: []member{
				{name: "old.jpg", size: 1, modTime: time.Date(1901, time.January, 1, 0, 0, 0, 0, time.UTC)},
				{name: "new.jpg", size: 1, modTime: time.Date(2200, time.January, 1, 0, 0, 0, 0, time.UTC)},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			want := writeArchive(t, tt.members)

			got := zipSize(tt.members)
			if got != want {
				t.Errorf("zipSize() = %d, archive/zip wrote %d (off by %d)", got, want, got-want)
			}
		})
	}
}

// The right length with a malformed central directory would pass TestZipSize
// and still hand the user a broken download.
func TestZipSizeArchivesAreReadable(t *testing.T) {
	body := strings.Repeat("x", 1024)

	var buf strings.Builder

	archive := zip.NewWriter(&buf)

	list := []member{
		{name: "portrait_mm.jpeg", size: int64(len(body)), modTime: fixedModTime},
		{name: "Midtøsten.jpg", size: int64(len(body)), modTime: fixedModTime},
	}

	for _, m := range list {
		w, err := archive.CreateHeader(storedHeader(m))
		if err != nil {
			t.Fatalf("CreateHeader(%q): %s", m.name, err)
		}

		_, err = io.WriteString(w, body)
		if err != nil {
			t.Fatalf("writing %q: %s", m.name, err)
		}
	}

	err := archive.Close()
	if err != nil {
		t.Fatalf("closing archive: %s", err)
	}

	if int64(buf.Len()) != zipSize(list) {
		t.Fatalf("archive is %d bytes, zipSize() said %d", buf.Len(), zipSize(list))
	}

	raw := buf.String()

	reader, err := zip.NewReader(strings.NewReader(raw), int64(len(raw)))
	if err != nil {
		t.Fatalf("reopening the archive: %s", err)
	}

	if len(reader.File) != len(list) {
		t.Fatalf("archive holds %d entries, want %d", len(reader.File), len(list))
	}

	for i, f := range reader.File {
		if f.Name != list[i].name {
			t.Errorf("entry %d is named %q, want %q", i, f.Name, list[i].name)
		}

		if f.Method != zip.Store {
			t.Errorf("entry %q uses method %d, want Store", f.Name, f.Method)
		}

		if !f.Modified.Equal(fixedModTime) {
			t.Errorf("entry %q modified %s, want %s", f.Name, f.Modified, fixedModTime)
		}

		rc, err := f.Open()
		if err != nil {
			t.Fatalf("opening %q: %s", f.Name, err)
		}

		got, err := io.ReadAll(rc)
		rc.Close()

		if err != nil {
			t.Fatalf("reading %q: %s", f.Name, err)
		}

		if string(got) != body {
			t.Errorf("entry %q round-tripped %d bytes, want %d", f.Name, len(got), len(body))
		}
	}
}

// One struct decodes all three shapes. Where it shows up if Munin drifts.
func TestPlanDecodesEveryCollectionShape(t *testing.T) {
	tests := []struct {
		name    string
		doc     string
		want    string
		entries []string
	}{
		{
			name:    "album index",
			doc:     "root/Misc/index.json",
			want:    "Misc.zip",
			entries: []string{"portrait_mm.jpeg", "test_special_chars.jpg"},
		},
		{
			name:    "keyword page",
			doc:     "keywords/Spring.json",
			want:    "Spring.zip",
			entries: []string{"portrait_mm.jpeg"},
		},
		{
			// Munin writes person files with the same encoder into the same
			// keywords/ directory, which is why one page type serves both.
			name:    "person page",
			doc:     "keywords/Martin_Peter_Meuche.json",
			want:    "Martin Peter Meuche.zip",
			entries: []string{"portrait_mm.jpeg"},
		},
		{
			name:    "non-ASCII keyword",
			doc:     "keywords/Midtøsten.json",
			want:    "Midtøsten.zip",
			entries: []string{"test_special_chars.jpg"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			name, members, err := plan(galleryRoot, tt.doc)
			if err != nil {
				t.Fatalf("plan(%q): %s", tt.doc, err)
			}

			if name != tt.want {
				t.Errorf("archive name = %q, want %q", name, tt.want)
			}

			if len(members) != len(tt.entries) {
				t.Fatalf("plan(%q) returned %d members, want %d", tt.doc, len(members), len(tt.entries))
			}

			for i, m := range members {
				if m.name != tt.entries[i] {
					t.Errorf("member %d is named %q, want %q", i, m.name, tt.entries[i])
				}

				// Zero means the symlink resolved to something empty.
				if m.size == 0 {
					t.Errorf("member %q has size 0", m.name)
				}

				// zipSize counts the extra field a set Modified produces.
				if m.modTime.IsZero() {
					t.Errorf("member %q has no mtime", m.name)
				}
			}
		})
	}
}

// root/index.json holds sub-albums and no photos of its own, so it must come
// back as errNoPhotos rather than a recursive crawl of the gallery.
func TestPlanDoesNotRecurseIntoSubAlbums(t *testing.T) {
	_, _, err := plan(galleryRoot, "root/index.json")
	if !errors.Is(err, errNoPhotos) {
		t.Fatalf("plan(root/index.json) error = %v, want errNoPhotos", err)
	}
}

func TestPlanRejectsUnsafeAndNonCollectionPaths(t *testing.T) {
	tests := []struct {
		name string
		doc  string
		want error
	}{
		{name: "parent traversal", doc: "../munin.json", want: errUnsafePath},
		{name: "deep traversal", doc: "root/../../munin.json", want: errUnsafePath},
		{name: "absolute path", doc: "/etc/passwd.json", want: errUnsafePath},
		{name: "dot segment", doc: "./root/Misc/index.json", want: errUnsafePath},
		{name: "doubled separator", doc: "root//Misc/index.json", want: errUnsafePath},
		{name: "embedded NUL", doc: "root/Misc/index.json\x00.json", want: errUnsafePath},
		{name: "not json", doc: "root/Misc/portrait_mm_180.jpeg", want: errNotJSON},
		{name: "no extension", doc: "root/Misc", want: errNotJSON},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := plan(galleryRoot, tt.doc)
			if !errors.Is(err, tt.want) {
				t.Errorf("plan(%q) error = %v, want %v", tt.doc, err, tt.want)
			}
		})
	}
}

// A zip that silently drops photos is indistinguishable from a complete one
// once downloaded, and the usual cause is a deployment fault worth seeing.
func TestPlanFailsWhenAnOriginalIsMissing(t *testing.T) {
	dir := t.TempDir()

	err := os.MkdirAll(filepath.Join(dir, "root/Misc"), 0o755)
	if err != nil {
		t.Fatal(err)
	}

	doc := `{"name":"Misc","url":"root/Misc/index.json","photos":[
	  {"url":"root/Misc/a.json","originalImageURL":"root/Misc/a_original.jpg"}
	]}`

	err = os.WriteFile(filepath.Join(dir, "root/Misc/index.json"), []byte(doc), 0o600)
	if err != nil {
		t.Fatal(err)
	}

	// What a content-only deployment, or an unmounted source volume, looks like.
	_, _, err = plan(dir, "root/Misc/index.json")
	if !errors.Is(err, errNoOriginals) {
		t.Fatalf("plan() error = %v, want errNoOriginals", err)
	}
}

func TestArchiveName(t *testing.T) {
	tests := []struct {
		name string
		want string
	}{
		{name: "Misc", want: "Misc.zip"},
		{name: "Martin Peter Meuche", want: "Martin Peter Meuche.zip"},
		{name: "Midtøsten", want: "Midtøsten.zip"},
		{name: "", want: "photos.zip"},
		{name: "   ", want: "photos.zip"},
		{name: ".", want: "photos.zip"},
		{name: "..", want: "photos.zip"},
		// Separators change what the filename means.
		{name: "a/b", want: "a-b.zip"},
		{name: "../etc/passwd", want: "..-etc-passwd.zip"},
		{name: `a\b`, want: "a-b.zip"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := archiveName(tt.name)
			if got != tt.want {
				t.Errorf("archiveName(%q) = %q, want %q", tt.name, got, tt.want)
			}
		})
	}
}

// archiveName folds separators and nothing else; FormatMediaType is what makes
// the value header-safe. Assert that rather than trusting it.
func TestArchiveNameCannotInjectAHeader(t *testing.T) {
	for _, name := range []string{
		"evil\r\nX-Injected: yes",
		"quote\"name",
		"Midtøsten",
		"tab\there",
		"semi;colon",
	} {
		t.Run(name, func(t *testing.T) {
			header := mime.FormatMediaType("attachment", map[string]string{
				"filename": archiveName(name),
			})

			raw := "HTTP/1.1 200 OK\r\nContent-Disposition: " + header + "\r\nContent-Length: 0\r\n\r\n"

			resp, err := http.ReadResponse(bufio.NewReader(strings.NewReader(raw)), nil)
			if err != nil {
				t.Fatalf("header %q produced an unparseable response: %s", header, err)
			}

			defer resp.Body.Close()

			if got := resp.Header.Get("X-Injected"); got != "" {
				t.Errorf("name %q injected X-Injected: %q", name, got)
			}

			// Nothing smuggled in alongside the two expected headers.
			if len(resp.Header) != 2 {
				t.Errorf("name %q produced %d headers, want 2: %v", name, len(resp.Header), resp.Header)
			}

			// Safe is not enough; the name must survive.
			_, params, err := mime.ParseMediaType(header)
			if err != nil {
				t.Fatalf("reparsing %q: %s", header, err)
			}

			if params["filename"] == "" {
				t.Errorf("name %q lost its filename entirely: %q", name, header)
			}
		})
	}
}

func TestEntryName(t *testing.T) {
	tests := []struct {
		name     string
		photo    string
		original string
		want     string
	}{
		{
			name:     "recovers the photographer's filename",
			photo:    "root/Misc/portrait_mm.json",
			original: "root/Misc/portrait_mm_original.jpeg",
			want:     "portrait_mm.jpeg",
		},
		{
			name:     "keeps the original's extension, not the json's",
			photo:    "root/Misc/test_special_chars.json",
			original: "root/Misc/test_special_chars_original.jpg",
			want:     "test_special_chars.jpg",
		},
		{
			name:     "non-ASCII names survive",
			photo:    "root/Midtøsten/vår.json",
			original: "root/Midtøsten/vår_original.jpg",
			want:     "vår.jpg",
		},
		{
			name:     "an original with no extension falls back",
			photo:    "root/Misc/portrait_mm.json",
			original: "root/Misc/portrait_mm_original",
			want:     "portrait_mm_original",
		},
		{
			name:     "an empty photo url falls back",
			photo:    "",
			original: "root/Misc/portrait_mm_original.jpeg",
			want:     "portrait_mm_original.jpeg",
		},
		{
			name:     "a photo url that is only a separator falls back",
			photo:    "/",
			original: "root/Misc/portrait_mm_original.jpeg",
			want:     "portrait_mm_original.jpeg",
		},
		{
			name:     "a bare json name still works",
			photo:    "portrait_mm.json",
			original: "portrait_mm_original.jpeg",
			want:     "portrait_mm.jpeg",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := entryName(tt.photo, tt.original)
			if got != tt.want {
				t.Errorf("entryName(%q, %q) = %q, want %q", tt.photo, tt.original, got, tt.want)
			}
		})
	}
}

// Keyword and person collections draw from the whole gallery, so names
// collide; several zip readers silently keep only one of a duplicate pair.
func TestDeduplicate(t *testing.T) {
	tests := []struct {
		name  string
		names []string
		want  []string
	}{
		{
			name:  "nothing to do",
			names: []string{"a.jpg", "b.jpg"},
			want:  []string{"a.jpg", "b.jpg"},
		},
		{
			name:  "one collision",
			names: []string{"IMG_0001.jpg", "IMG_0001.jpg"},
			want:  []string{"IMG_0001.jpg", "IMG_0001 (2).jpg"},
		},
		{
			name:  "three of a kind",
			names: []string{"IMG_0001.jpg", "IMG_0001.jpg", "IMG_0001.jpg"},
			want:  []string{"IMG_0001.jpg", "IMG_0001 (2).jpg", "IMG_0001 (3).jpg"},
		},
		{
			// Must not collide with a real photo already carrying it.
			name:  "generated name is itself taken",
			names: []string{"IMG_0001.jpg", "IMG_0001 (2).jpg", "IMG_0001.jpg"},
			want:  []string{"IMG_0001.jpg", "IMG_0001 (2).jpg", "IMG_0001 (3).jpg"},
		},
		{
			name:  "extension is preserved",
			names: []string{"vår.jpeg", "vår.jpeg"},
			want:  []string{"vår.jpeg", "vår (2).jpeg"},
		},
		{
			name:  "no extension",
			names: []string{"photo", "photo"},
			want:  []string{"photo", "photo (2)"},
		},
		{
			name:  "independent names are untouched",
			names: []string{"a.jpg", "b.jpg", "a.jpg", "b.jpg"},
			want:  []string{"a.jpg", "b.jpg", "a (2).jpg", "b (2).jpg"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			list := make([]member, 0, len(tt.names))
			for _, n := range tt.names {
				list = append(list, member{name: n})
			}

			deduplicate(list)

			if len(list) != len(tt.want) {
				t.Fatalf("deduplicate returned %d members, want %d", len(list), len(tt.want))
			}

			for i, m := range list {
				if m.name != tt.want[i] {
					t.Errorf("member %d is named %q, want %q", i, m.name, tt.want[i])
				}
			}

			seen := map[string]bool{}
			for _, m := range list {
				if seen[m.name] {
					t.Errorf("duplicate name %q survived", m.name)
				}

				seen[m.name] = true
			}
		})
	}
}

// gallery writes a one-photo collection whose original is produced by make,
// so each pre-flight fault can be built without repeating the JSON.
func gallery(t *testing.T, build func(path string)) string {
	t.Helper()

	dir := t.TempDir()

	err := os.MkdirAll(filepath.Join(dir, "root/Misc/originals"), 0o755)
	if err != nil {
		t.Fatal(err)
	}

	doc := `{"name":"Misc","url":"root/Misc/a.json","photos":[
	  {"url":"root/Misc/a.json","originalImageURL":"root/Misc/originals/a_original.jpg"}
	]}`

	err = os.WriteFile(filepath.Join(dir, "root/Misc/index.json"), []byte(doc), 0o600)
	if err != nil {
		t.Fatal(err)
	}

	build(filepath.Join(dir, "root/Misc/originals/a_original.jpg"))

	return dir
}

// The fault this whole branch exists for. os.Stat succeeds on a file that is
// readable only by another user, so a pre-flight that only stats would answer
// 200 with a size and then die mid-stream — the button appears, the download
// fails, and the operator hunts a streaming bug instead of a permission.
func TestPlanFailsWhenAnOriginalIsUnreadable(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root ignores the permission bits this test relies on")
	}

	tests := []struct {
		name string
		make func(t *testing.T, path string)
	}{
		{
			name: "file is unreadable",
			make: func(t *testing.T, path string) {
				t.Helper()

				err := os.WriteFile(path, []byte("jpeg"), 0o000)
				if err != nil {
					t.Fatal(err)
				}
			},
		},
		{
			name: "containing directory is untraversable",
			make: func(t *testing.T, path string) {
				t.Helper()

				err := os.WriteFile(path, []byte("jpeg"), 0o600)
				if err != nil {
					t.Fatal(err)
				}

				dir := filepath.Dir(path)

				err = os.Chmod(dir, 0o000)
				if err != nil {
					t.Fatal(err)
				}

				t.Cleanup(func() { _ = os.Chmod(dir, 0o755) })
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dir := gallery(t, func(path string) { tt.make(t, path) })

			_, _, err := plan(dir, "root/Misc/index.json")
			if !errors.Is(err, errNoOriginals) {
				t.Fatalf("plan() error = %v, want errNoOriginals", err)
			}

			if !errors.Is(err, fs.ErrPermission) {
				t.Errorf("plan() error = %v, want it to wrap fs.ErrPermission", err)
			}
		})
	}
}

// A FIFO stats as a non-directory, so a plan that only rejected directories
// would admit it and then block in open(2) forever, with the status and
// Content-Length already sent and no way for the request context to interrupt.
func TestPlanRejectsNonRegularOriginals(t *testing.T) {
	dir := gallery(t, func(path string) {
		err := syscall.Mkfifo(path, 0o644)
		if err != nil {
			t.Fatal(err)
		}
	})

	done := make(chan error, 1)

	go func() {
		_, _, err := plan(dir, "root/Misc/index.json")
		done <- err
	}()

	select {
	case err := <-done:
		if !errors.Is(err, errNoOriginals) {
			t.Fatalf("plan() error = %v, want errNoOriginals", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("plan() blocked on a FIFO instead of rejecting it")
	}
}

// originalImageURL is gallery data, not request data, but it is the one route
// by which a hand-edited or corrupt document could climb out of the gallery.
func TestPlanConfinesOriginalImageURL(t *testing.T) {
	dir := t.TempDir()

	err := os.MkdirAll(filepath.Join(dir, "root/Misc"), 0o755)
	if err != nil {
		t.Fatal(err)
	}

	for _, escape := range []string{"../../../../etc/passwd", "/etc/passwd", "root/../../x.jpg"} {
		t.Run(escape, func(t *testing.T) {
			doc := `{"name":"Misc","url":"root/Misc/index.json","photos":[
			  {"url":"root/Misc/a.json","originalImageURL":"` + escape + `"}
			]}`

			err := os.WriteFile(filepath.Join(dir, "root/Misc/index.json"), []byte(doc), 0o600)
			if err != nil {
				t.Fatal(err)
			}

			_, _, err = plan(dir, "root/Misc/index.json")
			if !errors.Is(err, errUnsafePath) {
				t.Errorf("plan() error = %v, want errUnsafePath", err)
			}
		})
	}
}

// A photo Munin rewrites between the pre-flight and the read must not produce a
// well-formed archive: shrinking would under-fill the declared Content-Length,
// and growing would ship a valid archive holding a silently truncated photo.
func TestWriteZipRejectsAFileResizedAfterPlanning(t *testing.T) {
	for _, tt := range []struct{ name, before, after string }{
		{name: "grew", before: "jpeg", after: "jpeg and then some"},
		{name: "shrank", before: "jpeg and then some", after: "j"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			dir := gallery(t, func(path string) {
				err := os.WriteFile(path, []byte(tt.before), 0o600)
				if err != nil {
					t.Fatal(err)
				}
			})

			_, members, err := plan(dir, "root/Misc/index.json")
			if err != nil {
				t.Fatalf("plan(): %s", err)
			}

			err = os.WriteFile(filepath.Join(dir, "root/Misc/originals/a_original.jpg"), []byte(tt.after), 0o600)
			if err != nil {
				t.Fatal(err)
			}

			err = writeZip(io.Discard, dir, members)
			if err == nil {
				t.Fatal("writeZip() succeeded on a file that changed size after planning")
			}
		})
	}
}
