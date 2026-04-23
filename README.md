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
            album = "/var/lib/munin/gallery";
            tailscaleKeyPath = "/run/secrets/hugin-tailscale-key";
          };
        }
      ];
    };
  };
}
```

## Development

Hugin is made with Elm and Node is required to install the compilers, and webpack.

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
`.pre-commit-config.yaml`. The current set covers prettier, gofmt,
golangci-lint, elm-format, nixpkgs-fmt and shellcheck. All tool binaries
are provided by the flake's devShell, so `nix develop` (or direnv)
must be active.

Install the git hook once per checkout:

    prek install

Run every hook against every tracked file:

    make lint

The same hooks run automatically on `git commit`.

### Environment variables

For all features of the Hugin to work, you need tokens for a few services:

- `HUGIN_MAPBOX_ACCESS_TOKEN` - For rendering maps on Album and Photos pages
- `HUGIN_ROLLBAR_ACCESS_TOKEN` - For runtime error reporting (can be ommitted)
- `HUGIN_SENTRY_DSN` For runtime error reporting (can be ommitted)

This should be exported as environment variables and will be picked up by webpack.

## Screenshots

<div width="100%">
<a href="screenshots/root.jpg"><img src="screenshots/root.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/albums.jpg"><img src="screenshots/albums.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/album.jpg"><img src="screenshots/album.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/photo.jpg"><img src="screenshots/photo.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/person.jpg"><img src="screenshots/person.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/keyword.jpg"><img src="screenshots/keyword.jpg?raw=true" align="left" width="250px" ></a>
</div>
