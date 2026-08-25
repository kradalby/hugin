package main

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"hash/crc32"
	"io"
	"io/fs"
	"mime"
	"net/http"
	"net/http/httptest"
	"os"
	"path"
	"path/filepath"
	"strings"
	"testing"
)

// The contract with Munin in one property: every URL Munin publishes has to
// resolve when hugin serves the gallery.
//
// Neither repo's unit tests can catch a break here. Munin asserts its URLs are
// relative and self-consistent; hugin asserts it decodes them. Both suites were
// green while every thumbnail 404'd in production, because the URLs were
// resolved against the wrong base. That is a property of the pair, so it needs
// a test that owns both halves.
//
// testdata/gallery is real Munin output, not hand-written: `munin` run over the
// two-photo album beside it. Regenerate both together — see testdata/README.md.

const galleryRoot = "testdata/gallery/content"

// publishedURLs pulls every URL-bearing value out of a decoded gallery JSON
// document. Recursive rather than typed, so a field Munin adds later is caught
// without teaching this test the schema.
func publishedURLs(node any, out *[]string) {
	switch value := node.(type) {
	case map[string]any:
		for key, child := range value {
			switch key {
			case "url", "originalImageURL", "previous", "next":
				if s, ok := child.(string); ok {
					*out = append(*out, s)

					continue
				}
				// Not a string: fall through and recurse, so a nested shape
				// Munin adds later is still walked.
			}

			publishedURLs(child, out)
		}
	case []any:
		for _, child := range value {
			publishedURLs(child, out)
		}
	}
}

// get keeps the call sites readable while carrying the test's context, which
// the linter requires over the http.Get convenience wrapper.
func get(t *testing.T, url string) *http.Response {
	t.Helper()

	req, err := http.NewRequestWithContext(t.Context(), http.MethodGet, url, nil)
	if err != nil {
		t.Fatalf("building request for %s: %s", url, err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET %s: %s", url, err)
	}

	return resp
}

func galleryURLs(t *testing.T) []string {
	t.Helper()

	seen := map[string]bool{}
	urls := []string{}

	root, err := os.OpenRoot(galleryRoot)
	if err != nil {
		t.Fatalf("opening %s: %s", galleryRoot, err)
	}
	defer root.Close()

	err = fs.WalkDir(root.FS(), ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(p, ".json") {
			return err
		}

		raw, err := fs.ReadFile(root.FS(), p)
		if err != nil {
			return err
		}

		var document any

		err = json.Unmarshal(raw, &document)
		if err != nil {
			return err
		}

		found := []string{}
		publishedURLs(document, &found)

		for _, u := range found {
			if !seen[u] {
				seen[u] = true
				urls = append(urls, u)
			}
		}

		return nil
	})
	if err != nil {
		t.Fatalf("walking %s: %s", galleryRoot, err)
	}

	if len(urls) == 0 {
		t.Fatalf("no published URLs found under %s; the fixture is empty or not Munin output", galleryRoot)
	}

	return urls
}

// The frontend prefixes /content (Data.Url.contentBase) and nothing else, so a
// published URL that is absolute or carries its own prefix cannot resolve no
// matter what the server does.
func TestPublishedURLsAreGalleryRelative(t *testing.T) {
	for _, u := range galleryURLs(t) {
		if strings.HasPrefix(u, "/") {
			t.Errorf("published URL is absolute, so /content would not be applied: %q", u)
		}

		if strings.HasPrefix(u, "content/") {
			t.Errorf("published URL carries its own content/ prefix, which would double up: %q", u)
		}
	}
}

// The regression that shipped: URLs that resolved against the current SPA route
// rather than the content mount, so every thumbnail 404'd.
func TestEveryPublishedURLResolvesThroughTheContentMount(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	for _, u := range galleryURLs(t) {
		t.Run(u, func(t *testing.T) {
			resp := get(t, server.URL+"/content/"+u)
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				t.Errorf("GET /content/%s = %d, want %d", u, resp.StatusCode, http.StatusOK)
			}
		})
	}
}

// rootUrl in Request/Helpers.elm. If Munin's gallery name or hugin's mount
// moves, this is the request that breaks first and takes the whole app with it.
func TestFrontendEntryPointResolves(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	resp := get(t, server.URL+"/content/root/index.json")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET /content/root/index.json = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var album struct {
		Name   string `json:"name"`
		Albums []struct {
			URL string `json:"url"`
		} `json:"albums"`
	}

	err := json.NewDecoder(resp.Body).Decode(&album)
	if err != nil {
		t.Fatalf("decoding the album index: %s", err)
	}

	if album.Name == "" {
		t.Error("album index decoded with an empty name")
	}

	// Following a link out of the index is what the frontend does next, and it
	// is where a prefix mismatch shows up as a 404 rather than a decode error.
	for _, sub := range album.Albums {
		resp := get(t, server.URL+"/content/"+sub.URL)
		resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("sub-album %s = %d, want %d", sub.URL, resp.StatusCode, http.StatusOK)
		}
	}
}

// The originals are read through Munin's symlinks, which point out of the
// served tree. That is the assumption that broke in production, so assert the
// bytes arrive rather than that the request succeeds.
func TestZipAlbumRoundTrips(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	resp := get(t, server.URL+"/zip/root/Misc/index.json")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET /zip/root/Misc/index.json = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	if got := resp.Header.Get("Content-Type"); got != "application/zip" {
		t.Errorf("Content-Type = %q, want application/zip", got)
	}

	if got := resp.Header.Get("Content-Disposition"); !strings.Contains(got, "Misc.zip") {
		t.Errorf("Content-Disposition = %q, want a Misc.zip filename", got)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("reading the archive: %s", err)
	}

	archive, err := zip.NewReader(bytes.NewReader(body), int64(len(body)))
	if err != nil {
		t.Fatalf("reopening the archive: %s", err)
	}

	// Archive carries the photographer's filenames, not the _original suffix.
	want := map[string]string{
		"portrait_mm.jpeg":       "root/Misc/portrait_mm_original.jpeg",
		"test_special_chars.jpg": "root/Misc/test_special_chars_original.jpg",
	}

	if len(archive.File) != len(want) {
		t.Fatalf("archive holds %d entries, want %d", len(archive.File), len(want))
	}

	for _, entry := range archive.File {
		source, ok := want[entry.Name]
		if !ok {
			t.Errorf("unexpected archive entry %q", entry.Name)

			continue
		}

		onDisk, err := os.ReadFile(filepath.Join(galleryRoot, source))
		if err != nil {
			t.Fatalf("reading %s: %s", source, err)
		}

		rc, err := entry.Open()
		if err != nil {
			t.Fatalf("opening %q: %s", entry.Name, err)
		}

		got, err := io.ReadAll(rc)
		rc.Close()

		if err != nil {
			t.Fatalf("reading %q: %s", entry.Name, err)
		}

		if !bytes.Equal(got, onDisk) {
			t.Errorf("entry %q holds %d bytes, want the %d bytes of %s",
				entry.Name, len(got), len(onDisk), source)
		}

		if entry.CRC32 != crc32.ChecksumIEEE(onDisk) {
			t.Errorf("entry %q has a CRC that does not match %s", entry.Name, source)
		}
	}
}

// An inexact Content-Length is worse than none: too large hangs the transfer,
// too small truncates. Only this proves the handler declares what it writes.
func TestZipContentLengthIsExact(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	for _, doc := range []string{
		"root/Misc/index.json",
		"keywords/Spring.json",
		"keywords/Martin_Peter_Meuche.json",
		"keywords/Midtøsten.json",
	} {
		t.Run(doc, func(t *testing.T) {
			resp := get(t, server.URL+"/zip/"+doc)
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				t.Fatalf("GET /zip/%s = %d, want %d", doc, resp.StatusCode, http.StatusOK)
			}

			// Chunked has no total, so the browser falls back to a spinner.
			if resp.TransferEncoding != nil {
				t.Errorf("Transfer-Encoding = %v, want none so the browser has a total", resp.TransferEncoding)
			}

			body, err := io.ReadAll(resp.Body)
			if err != nil {
				t.Fatalf("reading the archive: %s", err)
			}

			if resp.ContentLength != int64(len(body)) {
				t.Errorf("declared Content-Length %d, wrote %d bytes", resp.ContentLength, len(body))
			}

			_, err = zip.NewReader(bytes.NewReader(body), int64(len(body)))
			if err != nil {
				t.Errorf("archive does not reopen: %s", err)
			}
		})
	}
}

// The frontend hides its button unless HEAD answers application/zip, and takes
// the tooltip size from the same response.
func TestZipHeadMatchesGet(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	req, err := http.NewRequestWithContext(t.Context(), http.MethodHead, server.URL+"/zip/root/Misc/index.json", nil)
	if err != nil {
		t.Fatal(err)
	}

	head, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("HEAD: %s", err)
	}
	defer head.Body.Close()

	if head.StatusCode != http.StatusOK {
		t.Fatalf("HEAD = %d, want %d", head.StatusCode, http.StatusOK)
	}

	// Status alone is not enough: an nginx SPA fallback answers 200 text/html
	// for any path, giving a button that downloads index.html renamed .zip.
	if got := head.Header.Get("Content-Type"); got != "application/zip" {
		t.Errorf("HEAD Content-Type = %q, want application/zip", got)
	}

	// Through a server this proves nothing — net/http discards a HEAD body on
	// its own, so the handler could read the whole album off disk and no test
	// would see it. A recorder does not strip, so it does.
	rec := httptest.NewRecorder()
	zipHandler(galleryRoot).ServeHTTP(rec,
		httptest.NewRequestWithContext(t.Context(), http.MethodHead, "/root/Misc/index.json", nil))

	if rec.Body.Len() != 0 {
		t.Errorf("HEAD wrote %d bytes; it should not read the album at all", rec.Body.Len())
	}

	if got := rec.Header().Get("Content-Length"); got == "" {
		t.Error("HEAD set no Content-Length, so the frontend has no size to show")
	}

	full := get(t, server.URL+"/zip/root/Misc/index.json")
	defer full.Body.Close()

	if head.ContentLength != full.ContentLength {
		t.Errorf("HEAD Content-Length %d, GET %d", head.ContentLength, full.ContentLength)
	}

	if head.Header.Get("Content-Disposition") != full.Header.Get("Content-Disposition") {
		t.Errorf("HEAD Content-Disposition %q, GET %q",
			head.Header.Get("Content-Disposition"), full.Header.Get("Content-Disposition"))
	}
}

// A non-ASCII name has to survive into the saved filename, via RFC 2231.
func TestZipNonASCIICollection(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	resp := get(t, server.URL+"/zip/keywords/Midt%C3%B8sten.json")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET /zip/keywords/Midt%%C3%%B8sten.json = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	disposition := resp.Header.Get("Content-Disposition")

	_, params, err := mime.ParseMediaType(disposition)
	if err != nil {
		t.Fatalf("parsing Content-Disposition %q: %s", disposition, err)
	}

	if params["filename"] != "Midtøsten.zip" {
		t.Errorf("filename = %q, want %q", params["filename"], "Midtøsten.zip")
	}
}

// The collection path is the endpoint's whole trust boundary.
//
// Two layers refuse these: ServeMux normalises dot segments first, redirecting
// a real traversal out of /zip/ entirely, and whatever survives reaches
// filepath.Localize. Asserting "not 200" rather than a status, because how it
// is refused is an implementation detail and that nothing escapes is not.
func TestZipRefusesTraversal(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	for _, path := range []string{
		"/zip/../munin.json",
		"/zip/root/../../munin.json",
		"/zip/./../munin.json",
		"/zip/%2e%2e%2fmunin.json",
		"/zip/..%2f..%2fmunin.json",
		"/zip/root/%2e%2e/%2e%2e/munin.json",
		"/zip//etc/passwd.json",
		"/zip/root/Misc/index.json%00.json",
	} {
		t.Run(path, func(t *testing.T) {
			// Not parsed through url.Parse: rejection has to happen on the wire.
			resp := get(t, server.URL+path)
			defer resp.Body.Close()

			if resp.StatusCode == http.StatusOK {
				t.Errorf("GET %s = 200, want a refusal", path)
			}
		})
	}
}

// A dot segment resolving back inside the gallery is normalisation, not an
// attack. Recorded because it looks like the cases above but must not refuse.
func TestZipNormalisesHarmlessDotSegments(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	resp := get(t, server.URL+"/zip/./root/Misc/index.json")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("GET /zip/./root/Misc/index.json = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	if got := resp.Request.URL.Path; got != "/zip/root/Misc/index.json" {
		t.Errorf("normalised to %q, want %q", got, "/zip/root/Misc/index.json")
	}
}

// Everything that is not a leaf collection is a 404, including an album that
// only holds sub-albums — which is what stops this becoming a gallery crawl.
func TestZipRejectsNonCollections(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	for _, doc := range []string{
		"root/index.json",
		"root/Misc/portrait_mm_180.jpeg",
		"root/Misc/portrait_mm.json",
		"keywords/NoSuchKeyword.json",
		"root/Misc",
		"",
	} {
		t.Run(doc, func(t *testing.T) {
			resp := get(t, server.URL+"/zip/"+doc)
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusNotFound {
				t.Errorf("GET /zip/%s = %d, want %d", doc, resp.StatusCode, http.StatusNotFound)
			}
		})
	}
}

// Without Munin's source tree every original dangles. That must fail loudly
// rather than produce a valid archive holding nothing.
func TestZipWithoutOriginals(t *testing.T) {
	dir := t.TempDir()

	err := os.CopyFS(dir, os.DirFS(galleryRoot))
	if err != nil {
		t.Fatalf("copying the fixture: %s", err)
	}

	// os.CopyFS resolves symlinks, so break them explicitly.
	for _, name := range []string{
		"root/Misc/portrait_mm_original.jpeg",
		"root/Misc/test_special_chars_original.jpg",
	} {
		err = os.Remove(filepath.Join(dir, name))
		if err != nil {
			t.Fatalf("removing %s: %s", name, err)
		}
	}

	server := httptest.NewServer(routes(dir, ""))
	defer server.Close()

	resp := get(t, server.URL+"/zip/root/Misc/index.json")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("GET /zip/root/Misc/index.json = %d, want %d", resp.StatusCode, http.StatusNotFound)
	}
}

// --root-dir defaults to --content-dir, and /album/ is kept for anything still
// linking to it. Nothing covered either before.
func TestAlbumMountFallsBackToContentDir(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	for _, prefix := range []string{"/content", "/album"} {
		resp := get(t, server.URL+path.Join(prefix, "root/index.json"))
		resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("GET %s/root/index.json = %d, want %d", prefix, resp.StatusCode, http.StatusOK)
		}
	}
}

// Keyword and person collections draw from the whole gallery, so two albums
// that each hold an IMG_0001.jpg collide. Several readers silently keep only
// one of a duplicate pair, so the photo would vanish with no error anywhere.
// The committed fixture cannot collide, so this builds a gallery that does.
func TestZipDeduplicatesCollidingNames(t *testing.T) {
	dir := t.TempDir()

	for _, album := range []string{"One", "Two"} {
		err := os.MkdirAll(filepath.Join(dir, "root", album), 0o755)
		if err != nil {
			t.Fatal(err)
		}

		err = os.WriteFile(filepath.Join(dir, "root", album, "IMG_0001_original.jpg"),
			[]byte("photo from "+album), 0o600)
		if err != nil {
			t.Fatal(err)
		}
	}

	doc := `{"name":"Spring","url":"keywords/Spring.json","photos":[
	  {"url":"root/One/IMG_0001.json","originalImageURL":"root/One/IMG_0001_original.jpg"},
	  {"url":"root/Two/IMG_0001.json","originalImageURL":"root/Two/IMG_0001_original.jpg"}
	]}`

	err := os.MkdirAll(filepath.Join(dir, "keywords"), 0o755)
	if err != nil {
		t.Fatal(err)
	}

	err = os.WriteFile(filepath.Join(dir, "keywords/Spring.json"), []byte(doc), 0o600)
	if err != nil {
		t.Fatal(err)
	}

	server := httptest.NewServer(routes(dir, ""))
	defer server.Close()

	resp := get(t, server.URL+"/zip/keywords/Spring.json")
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}

	if resp.ContentLength != int64(len(body)) {
		t.Errorf("declared %d bytes, wrote %d", resp.ContentLength, len(body))
	}

	archive, err := zip.NewReader(bytes.NewReader(body), int64(len(body)))
	if err != nil {
		t.Fatalf("reopening the archive: %s", err)
	}

	if len(archive.File) != 2 {
		t.Fatalf("archive holds %d entries, want both photos", len(archive.File))
	}

	if archive.File[0].Name == archive.File[1].Name {
		t.Errorf("both entries are named %q, so a reader may keep only one", archive.File[0].Name)
	}
}

func TestZipRejectsOtherMethods(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	req, err := http.NewRequestWithContext(t.Context(), http.MethodPost,
		server.URL+"/zip/root/Misc/index.json", nil)
	if err != nil {
		t.Fatal(err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusMethodNotAllowed {
		t.Errorf("POST = %d, want %d", resp.StatusCode, http.StatusMethodNotAllowed)
	}

	if got := resp.Header.Get("Allow"); got != "GET, HEAD" {
		t.Errorf("Allow = %q, want %q", got, "GET, HEAD")
	}
}

// The capability probe's contract: no gallery, no mount, so the frontend hides
// the button instead of rendering one that 404s.
func TestZipIsNotMountedWithoutAGallery(t *testing.T) {
	server := httptest.NewServer(routes("", ""))
	defer server.Close()

	resp := get(t, server.URL+"/zip/root/Misc/index.json")
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK {
		t.Error("GET /zip/... = 200 without a gallery")
	}

	if got := resp.Header.Get("Content-Type"); strings.HasPrefix(got, "application/zip") {
		t.Errorf("Content-Type = %q, so the probe would show a button", got)
	}
}
