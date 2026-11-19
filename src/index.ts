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
  faImages,
} from "@fortawesome/free-solid-svg-icons";

library.add(
  faDownload,
  faInfoCircle,
  faChevronLeft,
  faChevronRight,
  faCaretSquareLeft,
  faCaretSquareRight,
  faImages,
);

dom.watch();

// see https://github.com/sindresorhus/screenfull.js/issues/126
import * as sf from "screenfull";
import { Screenfull } from "screenfull";
let screenfull = <Screenfull>sf;

///////////////////////////////////////////////////
// Error reporting and Analytics

// Errors from Elm land in the browser console. This used to go to Sentry,
// dropped because a supported SDK version costs ~0.7 MB of bundle to report
// errors that nobody collected: it no-op'd unless a DSN was baked in at build
// time, and nothing set one.
let log = {
  critical: function (val: string): void {
    console.error(`[CRITICAL]: ${val}`);
  },
  error: function (val: string): void {
    console.error(`[ERROR]: ${val}`);
  },
  warning: function (val: string): void {
    console.warn(`[WARNING]: ${val}`);
  },
  info: function (val: string): void {
    console.info(`[INFO]: ${val}`);
  },
  debug: function (val: string): void {
    console.debug(`[DEBUG]: ${val}`);
  },
};

///////////////////////////////////////////////////
//

// ELM
import { Elm } from "./Main.elm";

// The Umami tracker only wraps pushState/replaceState, so back/forward go
// unseen and its cached URL goes stale (a later push to the same page is then
// dropped as a repeat). A no-op replaceState re-syncs it and, after its own
// delay, reports the page; harmless when the tracker is absent.
window.addEventListener("popstate", () => {
  history.replaceState(history.state, "", location.href);
});

document.addEventListener("DOMContentLoaded", function () {
  let app = Elm.Main.init({
    node: document.getElementById("root"),
    flags: null,
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
