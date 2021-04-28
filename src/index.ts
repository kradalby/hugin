import placeholder from "url:./images/placeholder.png";
import loading from "url:./images/loading.svg";
import notFound from "url:./images/404.jpg";

console.log(placeholder, loading, notFound);

import initMap from "./map";

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
  faImages,
  faAngleRight,
} from "@fortawesome/free-solid-svg-icons";

library.add(
  faDownload,
  faInfoCircle,
  faChevronLeft,
  faChevronRight,
  faCaretSquareLeft,
  faCaretSquareRight,
  faSpinner,
  faImages,
  faAngleRight
);

dom.watch();

// see https://github.com/sindresorhus/screenfull.js/issues/126
import * as sf from "screenfull";
import { Screenfull } from "screenfull";
let screenfull = <Screenfull>sf;

///////////////////////////////////////////////////
// Error reporting and Analytics

import * as Sentry from "@sentry/browser";

Sentry.init({
  dsn: process.env.HUGIN_SENTRY_DSN,
});

let log = {
  critical: function (val: string): void {
    Sentry.captureMessage(`[CRITICAL]: ${val}`);
  },
  error: function (val: string): void {
    Sentry.captureMessage(`[ERROR]: ${val}`);
  },
  warning: function (val: string): void {
    Sentry.captureMessage(`[WARNING]: ${val}`);
  },
  info: function (val: string): void {
    Sentry.captureMessage(`[INFO]: ${val}`);
  },
  debug: function (val: string): void {
    Sentry.captureMessage(`[DEBUG]: ${val}`);
  },
};

import Analytics from "analytics";
import googleAnalytics from "@analytics/google-analytics";

const analytics = Analytics({
  app: "hugin",
  plugins: [
    googleAnalytics({
      trackingId: "UA-18856525-25",
    }),
  ],
});

///////////////////////////////////////////////////
//

// ELM
import { Elm } from "./Main.elm";

document.addEventListener("DOMContentLoaded", function () {
  let app = Elm.Main.init({
    node: document.getElementById("root"),
    flags: null,
  });

  // Download albums
  app.ports.downloadImages.subscribe((urls: [string]) => {
    // downloadImages(urls);
  });
  // Google Analytics
  app.ports.analytics.subscribe((url: string) => {
    console.log("DEBUG: gtag called with: ", url);
    analytics.page({ path: "/" + url });
  });

  app.ports.initMap.subscribe((data: [string, [number, number][]]) => {
    console.log("DEBUG: Elm Port initMap called");
    initMap(data);
  });
  app.ports.httpError.subscribe((val: string) => {
    log.error(val);
  });

  app.ports.requestFullscreen.subscribe(() => {
    screenfull.toggle();
  });
});
