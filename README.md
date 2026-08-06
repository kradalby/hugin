![Hugin](src/images/hugin_black.svg)

[Hugin](https://en.wikipedia.org/wiki/Huginn_and_Muninn) is one of a pair of ravens that fly all over the world, Midgard, and bring information to the god Odin.

Hugin is a front-end for image galleries generated with [Munin](https://github.com/kradalby/munin)

[Demo](https://hugindemo.kradalby.no/)

## Features

- Responsive design
- Display image metadata
- Display albums
- Explore images with people tag
- Explore images with keywords
- Fuzzy search keywords
- Use geodata from images to display map
- Slideshow modus for album

## Installation

Hugin can be hosted by all webservers that can serve static files, but does rely on a [Munin](https://github.com/kradalby/munin) generated gallery served under `/content` from the same domain.

For example

    https://hugin.example.no ⬅  Hugin static files
    https://hugin.example.no/content ⬅ Munin gallery

### Nginx

Here is an example configuration with Nginx:

```
server {
    listen 80 default_server;
    listen [::]:80 default_server;


    root /var/www/html;

    # Add index.php to the list if you are using PHP
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files $uri $uri/ =404;
    }

    location / {
        alias /var/www/hugin; # ⬅  Hugin static files
    }

    location /content {
        alias /storage/pictures/example/munin/content; # ⬅ Munin gallery
    }

}
```

### NixOS

The flake ships a NixOS module that wraps hugin in a systemd unit and
fronts it with a Tailscale sidecar for access control:

```nix
{
  inputs.hugin.url = "github:kradalby/hugin";

  outputs = { self, nixpkgs, hugin }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        hugin.nixosModules.default
        {
          services.hugin = {
            enable = true;
            # The directory Munin generated (its targetFolder), holding
            # root/ and keywords/.
            contentDir = "/var/lib/munin/gallery/content";
            tailscaleKeyPath = "/run/secrets/hugin-tailscale-key";
          };
        }
      ];
    };
  };
}
```

## Development

Hugin is made with Elm; Node is required to install the compilers and parcel.

To set up the development environment:

    make install

Run the development server (with hot reload):

    make dev

In addition to the development server, hugin needs a "api" from a [Munin](https://github.com/kradalby/munin) gallery to work. The easiest way to solve that is to use the Python HTTP server in a Munin directory. The node dev server is already configured to proxy it correctly from port 3000.

    cd <MUNIN GALLERY>
    python3 -m http.server 3000

Where `<MUNIN GALLERY>` is a directory containing a `root/` and a `keywords/` folder.

### Code style

Linters and formatters are driven by [prek](https://github.com/j178/prek)
(a drop-in, Rust-native replacement for pre-commit) and configured in
`.pre-commit-config.yaml`. Formatting runs through a single `treefmt`
entrypoint (gofumpt, goimports, nixfmt, prettier, elm-format); golangci-lint
and shellcheck run alongside it. All tool binaries are provided by the
flake's devShell, so `nix develop` (or direnv) must be active.

Install the git hook once per checkout:

    prek install

Run every hook against every tracked file:

    make lint

The same hooks run automatically on `git commit`.

### Continuous integration

[garnix](https://garnix.io) is the only CI, and it builds flake outputs
directly. A check is therefore added by adding it to `checks` in `flake.nix`,
not by editing a workflow, and `nix flake check` runs locally exactly what CI
runs:

    nix flake check

Test suites live there too — `gotest`, `elm-test`, `golangci-lint`,
`formatting`, `shellcheck` and `module-eval` are all flake checks.

prek is a local pre-commit concern rather than a CI one. Its formatting hooks
are covered by the `formatting` check and its shellcheck hook by the
`shellcheck` check; the remaining hygiene hooks (private keys, large files,
line endings) only run on `git commit`.

### Environment variables

Third-party tokens are read by the hugin server at runtime, not baked into
the bundle: every `HUGIN_TOKEN_<NAME>` variable in the server's environment is
served from `/tokens` as a lowercased `name` key, which the frontend fetches on
demand.

- `HUGIN_TOKEN_MAPBOX` - For rendering maps on Album and Photo pages

Under the NixOS module these belong in an `environmentFile`, so the token never
reaches the Nix store:

    services.hugin.environmentFile = "/run/secrets/hugin-tokens";

## Screenshots

<div width="100%">
<a href="screenshots/root.jpg"><img src="screenshots/root.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/albums.jpg"><img src="screenshots/albums.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/album.jpg"><img src="screenshots/album.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/photo.jpg"><img src="screenshots/photo.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/person.jpg"><img src="screenshots/person.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/keyword.jpg"><img src="screenshots/keyword.jpg?raw=true" align="left" width="250px" ></a>
</div>
