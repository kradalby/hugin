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
  faAngleRight,
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

import Analytics from "analytics";
import googleAnalytics from "@analytics/google-analytics";
import umamiAnalytics from "@binance-chain/analytics-plugin-umami";

const analytics = Analytics({
  app: "hugin",
  plugins: [
    umamiAnalytics({
      id: "2145b3cd-1fcf-496c-8b45-c43951ff9129",
      reportUri: "https://umami.kradalby.no",
    }),
    googleAnalytics({
      measurementIds: ["UA-18856525-25"],
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
