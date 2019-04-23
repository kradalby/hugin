declare const MAPBOX_ACCESS_TOKEN: string;
declare const SENTRY_DSN: string;
declare const ROLLBAR_ACCESS_TOKEN: string;
declare function gtag(
  config: string,
  id: string,
  info: {
    page_path: string;
  }
): void;
