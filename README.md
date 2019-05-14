![Hugin](src/images/hugin_black.svg)

[Hugin](https://en.wikipedia.org/wiki/Huginn_and_Muninn) is one of a pair of ravens that fly all over the world, Midgard, and bring information to the god Odin.

Hugin is a front-end for image galleries generated with [Munin](https://github.com/kradalby/munin)

[Demo](https://hugindemo.kradalby.no/)

## Features

- Show images on map if it has location data
- Responsive design
-

## Screenshots
<div width="100%">
<a href="screenshots/root.jpg"><img src="screenshots/root.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/albums.jpg"><img src="screenshots/albums.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/album.jpg"><img src="screenshots/album.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/photo.jpg"><img src="screenshots/photo.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/person.jpg"><img src="screenshots/person.jpg?raw=true" align="left" width="250px" ></a>
<a href="screenshots/keyword.jpg"><img src="screenshots/keyword.jpg?raw=true" align="left" width="250px" ></a>
</div>

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


### Kubernetes
The current setup of the Hugin demo is installed on [Kubernetes](https://kubernetes.io) with the `/content` served from a storage server and proxied. Following is an example of that setup adding the storage server as a Kubernetes service and setting up the Ingress.

A up to date [Hugin docker container can be found here](https://hub.docker.com/r/kradalby/hugin)

Munin service:
```
kind: Service
apiVersion: v1
metadata:
  name: munin-content-service
  namespace: hugin
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ExternalName
  externalName: storage.example.no
```

Ingress:
```
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hugin-ingress
  namespace: hugin
  annotations:
    ingress.kubernetes.io/ssl-redirect: "true"
    kubernetes.io/ingress.class: "nginx"
    kubernetes.io/tls-acme: "true"
spec:
  tls:
  - hosts:
    - hugin.example.no
    secretName: hugin-example-no-tls
  rules:
  - host: hugin.example.no
    http:
      paths:
      - path: /
        backend:
          serviceName: hugin-service
          servicePort: 80
      - path: /content
        backend:
          serviceName: munin-content-service
          servicePort: 80
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
When developing on the project, be sure to follow the standard setup of [elm-format](https://github.com/avh4/elm-format) and [elm-analyse](https://github.com/stil4m/elm-analyse)

All linters can be run with:

    make lint

All linters are ran on the CI whenever a change is comitted.

### Environment variables
For all features of the Hugin to work, you need tokens for a few services:

- `HUGIN_MAPBOX_ACCESS_TOKEN` - For rendering maps on Album and Photos pages
- `HUGIN_ROLLBAR_ACCESS_TOKEN` - For runtime error reporting (can be ommitted)
- `HUGIN_SENTRY_DSN` For runtime error reporting (can be ommitted)

This should be exported as environment variables and will be picked up by webpack.
