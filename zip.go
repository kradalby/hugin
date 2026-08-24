package main

import (
	"archive/zip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"mime"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// A file destined for the archive. Size and mtime are carried rather than
// re-stat'ed: stat'ing twice lets the declared length and the body disagree.
type member struct {
	name    string // name inside the archive
	source  string // gallery-relative path on disk
	size    int64
	modTime time.Time
}

// Fixed-size ZIP records, from the APPNOTE spec.
const (
	localHeaderSize   = 30
	centralHeaderSize = 46
	endRecordSize     = 22

	dataDescriptorSize      = 16
	dataDescriptorSize64    = 24
	zip64ExtraSize          = 28
	zip64EndRecordSize      = 56
	zip64EndLocatorSize     = 20
	zip64EndTotalRecordSize = zip64EndRecordSize + zip64EndLocatorSize

	// Values at or above these go zip64. archive/zip compares with >=, so the
	// limit itself is already over.
	zip64MagicValue      = math.MaxUint32
	zip64EntryCountMagic = math.MaxUint16
)

// Info-ZIP's 0x5455 extra as archive/zip writes it. Not APPNOTE, and not
// promised across Go releases; TestZipSize would catch a change.
const extendedTimestampSize = 9

// Exact length of the archive writeZip will produce, so the response can
// declare Content-Length and still stream. Predictable only because entries
// are stored and archive/zip emits sizes in a trailing descriptor, so no CRC
// pre-pass is needed. Every entry counts the extended-timestamp extra, which
// holds only because storedHeader guarantees it. TestZipSize pins the lot.
func zipSize(members []member) int64 {
	var localTotal, centralTotal int64

	needZip64 := len(members) >= zip64EntryCountMagic

	for _, m := range members {
		nameLen := int64(len(m.name))

		descriptor := int64(dataDescriptorSize)
		extra := int64(0)

		// archive/zip compares with >=, so uint32max itself is already zip64.
		if m.size >= zip64MagicValue {
			descriptor = dataDescriptorSize64
			extra = zip64ExtraSize
			needZip64 = true
		}

		// A large archive pushes later entries past the 32-bit offset limit
		// even when each file is small.
		if localTotal >= zip64MagicValue {
			extra = zip64ExtraSize
			needZip64 = true
		}

		localTotal += localHeaderSize + nameLen + extendedTimestampSize + m.size + descriptor
		centralTotal += centralHeaderSize + nameLen + extendedTimestampSize + extra
	}

	if centralTotal >= zip64MagicValue || localTotal >= zip64MagicValue {
		needZip64 = true
	}

	total := localTotal + centralTotal + endRecordSize
	if needZip64 {
		total += zip64EndTotalRecordSize
	}

	return total
}

// Munin's "_original" suffix is a gallery artefact, not a name anyone wants in
// their downloads. The photo JSON is named after the source file, so its
// basename plus the original's extension recovers what the photographer used.
func entryName(photoURL, originalURL string) string {
	fallback := path.Base(originalURL)

	base := strings.TrimSuffix(path.Base(photoURL), ".json")
	ext := path.Ext(originalURL)

	// Degenerate input falls back to a name that is at least real.
	if base == "" || base == "." || base == "/" || ext == "" {
		return foldSeparators(fallback)
	}

	return foldSeparators(base + ext)
}

// path.Base drops "/", but photoURL never passes through localize and a
// backslash is legal in a Linux filename, so "..\..\evil.jpg" would traverse
// on Windows extractors. NUL truncates names in C readers.
func foldSeparators(name string) string {
	return separatorFolder.Replace(name)
}

var separatorFolder = strings.NewReplacer("/", "-", `\`, "-", "\x00", "-")

// Keyword and person collections draw from the whole gallery, so names collide.
// Several zip readers silently keep only one of a duplicate pair, which would
// drop a photo with no error anywhere.
func deduplicate(members []member) {
	seen := make(map[string]int, len(members))

	for i, m := range members {
		count, clash := seen[m.name]
		if !clash {
			seen[m.name] = 1

			continue
		}

		ext := path.Ext(m.name)
		stem := strings.TrimSuffix(m.name, ext)

		// The gallery may already contain "IMG_0001 (2).jpg".
		for {
			count++
			candidate := fmt.Sprintf("%s (%d)%s", stem, count, ext)

			if _, taken := seen[candidate]; !taken {
				seen[m.name] = count
				seen[candidate] = 1
				members[i].name = candidate

				break
			}
		}
	}
}

// Album index.json and keywords/<tag>.json share this shape — a person page is
// one of the latter, not a third kind.
// Not decoding "albums" is what makes "leaf nodes only" a property of the type
// rather than a rule to remember.
type collection struct {
	Name   string `json:"name"`
	Photos []struct {
		URL              string `json:"url"`
		OriginalImageURL string `json:"originalImageURL"`
	} `json:"photos"`
}

var (
	errNoPhotos    = errors.New("collection lists no photos")
	errNotJSON     = errors.New("collection path is not a .json document")
	errUnsafePath  = errors.New("path escapes the gallery")
	errNoOriginals = errors.New("collection has photos with no readable original")
	errResized     = errors.New("original changed size after it was planned")
)

// Confines a gallery-relative path. Not os.Root, the obvious choice: Munin
// symlinks originals out of the gallery, so os.Root rejects every one of them.
//
// Takes the path exactly as given. Trimming a leading separator here would
// turn "/etc/passwd.json" into an accepted gallery path; a trust boundary must
// refuse hostile input, not clean it.
func localize(rel string) (string, error) {
	local, err := filepath.Localize(rel)
	if err != nil {
		return "", fmt.Errorf("%w: %q", errUnsafePath, rel)
	}

	return local, nil
}

// Collection names come from directories and keywords, so they carry anything a
// filesystem allows. Separators, NUL and the dot names change what the filename
// means; everything else is left exactly as the gallery has it.
func archiveName(name string) string {
	cleaned := strings.Map(func(r rune) rune {
		if r == '/' || r == '\\' || r == 0 {
			return '-'
		}

		return r
	}, name)

	cleaned = strings.TrimSpace(cleaned)
	if cleaned == "" || cleaned == "." || cleaned == ".." {
		// Not "album": this same handler serves keyword and person collections.
		return "photos.zip"
	}

	return cleaned + ".zip"
}

// The failing path is the symlink, which is world-readable, so "permission
// denied" about it reads as nonsense. Readlink still works when the target's
// directory does not, unlike EvalSymlinks.
func describeOriginal(abs, url string, err error) error {
	link, lerr := os.Readlink(abs)
	if lerr == nil {
		target := link
		if !filepath.IsAbs(target) {
			target = filepath.Join(filepath.Dir(abs), target)
		}

		return fmt.Errorf("%w: %q -> %q: %w", errNoOriginals, url, target, err)
	}

	return fmt.Errorf("%w: %q: %w", errNoOriginals, url, err)
}

// Resolves a collection document into the archive name and its members.
//
// Everything is checked before a byte is written: that is what allows an exact
// Content-Length, and turns a gallery fault into a 404 rather than a download
// that dies with the headers sent. One bad original fails the whole request —
// a silently incomplete zip looks identical to a complete one.
func plan(dir, docPath string) (string, []member, error) {
	if path.Ext(docPath) != ".json" {
		return "", nil, fmt.Errorf("%w: %q", errNotJSON, docPath)
	}

	local, err := localize(docPath)
	if err != nil {
		return "", nil, err
	}

	// G304: confined by localize above.
	raw, err := os.ReadFile(filepath.Join(dir, local)) //nolint:gosec
	if err != nil {
		return "", nil, fmt.Errorf("reading collection %q: %w", docPath, err)
	}

	var doc collection

	err = json.Unmarshal(raw, &doc)
	if err != nil {
		return "", nil, fmt.Errorf("decoding collection %q: %w", docPath, err)
	}

	if len(doc.Photos) == 0 {
		return "", nil, fmt.Errorf("%w: %q", errNoPhotos, docPath)
	}

	members := make([]member, 0, len(doc.Photos))

	for _, photo := range doc.Photos {
		// Operator-supplied, but a malformed gallery is the one route by which
		// a path could climb out, so confined on the same terms as the request.
		original, err := localize(photo.OriginalImageURL)
		if err != nil {
			return "", nil, err
		}

		abs := filepath.Join(dir, original)

		// Stat first: os.Open on a FIFO blocks until a writer appears, and no
		// request context can interrupt that.
		info, err := os.Stat(abs)
		if err != nil {
			return "", nil, describeOriginal(abs, photo.OriginalImageURL, err)
		}

		if !info.Mode().IsRegular() {
			return "", nil, fmt.Errorf("%w: %q is not a regular file", errNoOriginals, photo.OriginalImageURL)
		}

		// Stat does not prove readability: a 0640 original stats fine and opens
		// EACCES, which is the exact fault this pre-flight exists to catch.
		// G304: confined by localize above.
		probe, err := os.Open(abs) //nolint:gosec
		if err != nil {
			return "", nil, describeOriginal(abs, photo.OriginalImageURL, err)
		}

		probe.Close()

		members = append(members, member{
			name:    entryName(photo.URL, photo.OriginalImageURL),
			source:  original,
			size:    info.Size(),
			modTime: info.ModTime(),
		})
	}

	// Before the caller measures: each rename adds 4 bytes to both headers, so
	// measuring first would under-declare by 8 per collision.
	deduplicate(members)

	return archiveName(doc.Name), members, nil
}

// Stored, not deflated: JPEGs are already entropy-coded, and deflate would
// make the length unpredictable.
//
// Modified is forced non-zero, and Extra left unset, because zipSize counts
// exactly one 9-byte extra per entry. A zero mtime would leave the body 18
// bytes short per entry of the Content-Length already sent.
//
// Store costs one thing: Java's ZipInputStream refuses a stored entry with a
// data descriptor. Its ZipFile, and every other reader tried, are fine.
func storedHeader(m member) *zip.FileHeader {
	modified := m.modTime
	if modified.IsZero() {
		modified = msdosEpoch
	}

	return &zip.FileHeader{
		Name:     m.name,
		Method:   zip.Store,
		Modified: modified,
	}
}

// Used only when a file has no mtime at all. One merely outside the MS-DOS
// range is left alone: archive/zip clamps and still writes the extra.
var msdosEpoch = time.Date(1980, time.January, 1, 0, 0, 0, 0, time.UTC)

// Streams a collection's originals. Nothing accumulates, so heap scales with
// photo count, not bytes moved.
//
// The length is computed rather than dry-run because HEAD doubles as the
// frontend's probe on every page view, so it must stay O(photos) rather than
// reading the album. Only a Go-served gallery answers application/zip.
func zipHandler(dir string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.Header().Set("Allow", "GET, HEAD")
			http.Error(w, "405 method not allowed", http.StatusMethodNotAllowed)

			return
		}

		// StripPrefix leaves the path rooted; localize refuses to trim it.
		docPath := strings.TrimPrefix(r.URL.Path, "/")

		name, members, err := plan(dir, docPath)
		if err != nil {
			// Always 404: telling a prober which paths exist buys nothing.
			// Both verbs quote — the error carries the decoded request path and
			// fs.ValidPath permits newlines, so %s would forge log lines.
			// errNoPhotos/errNotJSON are ordinary answers to a per-page-view
			// probe, not faults worth a line each time.
			switch {
			case errors.Is(err, errNoPhotos), errors.Is(err, errNotJSON):
				if *verbose {
					log.Printf("zip %q: %q", docPath, err.Error()) //nolint:gosec
				}
			default:
				log.Printf("zip %q: %q", docPath, err.Error()) //nolint:gosec
			}

			http.NotFound(w, r)

			return
		}

		total := zipSize(members)

		// FormatMediaType percent-encodes CRLF and emits RFC 2231 for
		// non-ASCII, so a Munin-derived name cannot inject a header.
		disposition := mime.FormatMediaType("attachment", map[string]string{"filename": name})

		w.Header().Set("Content-Type", "application/zip")
		w.Header().Set("Content-Length", strconv.FormatInt(total, 10))
		w.Header().Set("Content-Disposition", disposition)
		// A cached probe would show a stale tooltip, and nothing should store a
		// multi-gigabyte body.
		w.Header().Set("Cache-Control", "no-store")
		// Advisory only: wget -c ignores it. What saves a resume is the archive
		// being byte-deterministic.
		w.Header().Set("Accept-Ranges", "none")

		// Cost, not protocol: net/http discards a HEAD body anyway, but without
		// this every probe reads the whole album off disk to feed it.
		if r.Method == http.MethodHead {
			return
		}

		err = writeZip(w, dir, members)
		if err != nil {
			// Headers are long gone, so there is no status left to set.
			// Aborting makes the browser report a failed download instead of
			// leaving a truncated archive.
			if r.Context().Err() == nil {
				log.Printf("zip %q: streaming: %q", docPath, err.Error()) //nolint:gosec
			}

			panic(http.ErrAbortHandler)
		}
	})
}

// writeZip streams the manifest into w as a stored zip archive.
func writeZip(w io.Writer, dir string, members []member) error {
	archive := zip.NewWriter(w)

	for _, m := range members {
		entry, err := archive.CreateHeader(storedHeader(m))
		if err != nil {
			return fmt.Errorf("creating entry %q: %w", m.name, err)
		}

		// G304: confined by localize in plan.
		file, err := os.Open(filepath.Join(dir, m.source)) //nolint:gosec
		if err != nil {
			return fmt.Errorf("opening %q: %w", m.source, err)
		}

		// CopyN, not Copy: a photo rewritten mid-download must not desync the
		// body from the sent Content-Length. Shrinking returns io.EOF; growing
		// would ship a well-formed archive holding a truncated photo, hence the
		// probe for one byte too many.
		_, err = io.CopyN(entry, file, m.size)
		if err == nil {
			var extra [1]byte

			n, _ := file.Read(extra[:])
			if n > 0 {
				err = fmt.Errorf("%w: grew past %d bytes", errResized, m.size)
			}
		}

		closeErr := file.Close()

		if err != nil {
			return fmt.Errorf("streaming %q: %w", m.source, err)
		}

		if closeErr != nil {
			return fmt.Errorf("closing %q: %w", m.source, closeErr)
		}
	}

	err := archive.Close()
	if err != nil {
		return fmt.Errorf("finishing archive: %w", err)
	}

	return nil
}
