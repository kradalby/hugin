// require('./styles/reset.css');
// require('materialize-css/sass/materialize.scss')

// FONT AWESOME
import { library, dom } from "@fortawesome/fontawesome-svg-core";
import {
  faDownload,
  faInfoCircle,
  faChevronLeft,
  faChevronRight,
  faCaretSquareLeft,
  faCaretSquareRight,
  faSpinner,
  faAngleRight
} from "@fortawesome/free-solid-svg-icons";

library.add(
  faDownload,
  faInfoCircle,
  faChevronLeft,
  faChevronRight,
  faCaretSquareLeft,
  faCaretSquareRight,
  faSpinner,
  faAngleRight
);

dom.watch();

// SCSS
require("./styles.scss");

require("./images/placeholder.png");
require("./images/loading.svg");
require("./images/404.jpg");

// BOOTSTRAP
// require("bootstrap/js/dist/modal");

///////////////////////////////////////////////////
// Error reporting

import * as Sentry from "@sentry/browser";

Sentry.init({
  dsn: SENTRY_DSN
});

import * as Rollbar from "rollbar";

let rollbar = new Rollbar({
  accessToken: ROLLBAR_ACCESS_TOKEN,
  captureUncaught: true,
  captureUnhandledRejections: true
});

let log = {
  critical: function(val: string): void {
    rollbar.critical(val);
    Sentry.captureMessage(`[CRITICAL]: ${val}`);
  },
  error: function(val: string): void {
    rollbar.error(val);
    Sentry.captureMessage(`[ERROR]: ${val}`);
  },
  warning: function(val: string): void {
    rollbar.warning(val);
    Sentry.captureMessage(`[WARNING]: ${val}`);
  },
  info: function(val: string): void {
    rollbar.info(val);
    Sentry.captureMessage(`[INFO]: ${val}`);
  },
  debug: function(val: string): void {
    rollbar.debug(val);
    Sentry.captureMessage(`[DEBUG]: ${val}`);
  }
};

///////////////////////////////////////////////////
//

// ELM
import { Elm } from "./Main";

document.addEventListener("DOMContentLoaded", function() {
  let app = Elm.Main.init({
    node: document.getElementById("root"),
    flags: null
  });

  // Download albums
  app.ports.downloadImages.subscribe(urls => {
    downloadImages(urls);
  });
  // Google Analytics
  app.ports.analytics.subscribe(url => {
    console.log("DEBUG: gtag called with: ", url);
    gtag("config", "UA-18856525-25", { page_path: "/" + url });
  });

  app.ports.initMap.subscribe(data => {
    console.log("DEBUG: Elm Port initMap called");
    initMap(data);
  });
  app.ports.httpError.subscribe(val => {
    log.error(val);
  });
});

// Helper functions
function rafAsync() {
  return new Promise(resolve => {
    requestAnimationFrame(resolve); // faster than set time out
  });
}

function checkElementById(selector: string): Promise<HTMLElement | null> {
  if (document.getElementById(selector) === null) {
    return rafAsync().then(() => checkElementById(selector));
  } else {
    return Promise.resolve(document.getElementById(selector));
  }
}

// MAPBOX
require("mapbox-gl/dist/mapbox-gl.css");
let mapboxgl = require("mapbox-gl");
mapboxgl.accessToken = MAPBOX_ACCESS_TOKEN;

let map: mapboxgl.Map | null = null;

// coordinates: [Name : String, [[-80.425, 46.437], [-71.516, 46.437]] : List ( Float, Float ) ]
function initMap(data: [string, [number, number][]]) {
  console.log("DEBUG: initMap called with: ", data);

  // ----------------------------------------------
  // Clean up maps and old maps
  //

  // Try to force some garbage collection
  if (map) {
    map.remove();
    map = null;
  }

  // Ugly hack to remove not garbage collected rouge maps
  document.querySelectorAll("[class^=mapboxgl]").forEach(element => {
    if (element.parentNode !== null) {
      element.parentNode.removeChild(element);
    }
  });

  // ----------------------------------------------

  let divName = "map-" + data[0];
  let coordinates = data[1];

  checkElementById(divName).then(() => {
    // Create map
    map = new mapboxgl.Map({
      container: divName,
      style: "mapbox://styles/mapbox/light-v9",
      zoom: 13,
      interactive: false,
      maxZoom: 10,
      minZoom: 2
    });

    let bounds = new mapboxgl.LngLatBounds();

    // Draw markers
    coordinates.forEach(coordinate => {
      new mapboxgl.Marker().setLngLat(coordinate).addTo(map);

      bounds.extend(coordinate);
    });
    if (map) {
      map.fitBounds(bounds, {
        padding: { top: 65, bottom: 50, left: 50, right: 50 },
        linear: false,
        maxZoom: 10
      });
    }
  });
}

// FILE DOWNLOAD

// let saveAs = require('./FileSaver.js')
require("web-streams-polyfill");
let StreamSaver = require("streamsaver");

let JSZip = require("jszip");
let JSZipUtils = require("jszip-utils");

function urlToPromise(url: string) {
  return new Promise(function(resolve, reject) {
    JSZipUtils.getBinaryContent(url, function(err: Error, data: Uint8Array) {
      if (err) {
        reject(err);
      } else {
        resolve(data);
      }
    });
  });
}

function downloadImages(urls: string[]) {
  console.log("Download images is called with: ", urls);
  let zip = new JSZip();
  const fileStream = StreamSaver.createWriteStream("download.zip");
  const writer = fileStream.getWriter();

  urls.forEach(url => {
    let filename = url.replace(/.*\//g, "");
    zip.file(filename, urlToPromise(url), { binary: true });
  });

  zip
    .generateInternalStream({ type: "uint8array", streamFiles: true })
    .on("data", (data: Uint8Array) => {
      writer.write(data);
      // writer.write(new Blob([data]))
    })
    .on("end", () => {
      console.log("Reached end of zip stream");
      writer.close();
    })
    .on("error", (error: Error) => {
      console.log(error);
      writer.abort(error);
    })
    .resume();

  return false;
}
