// WARNING: Do not manually modify this file. It was generated using:
// https://github.com/dillonkearns/elm-typescript-interop
// Type definitions for Elm ports

export namespace Elm {
  namespace Main {
    export interface App {
      ports: {
        downloadImages: {
          subscribe(callback: (data: string[]) => void): void;
        };
        initMap: {
          subscribe(
            callback: (data: [string, [number, number][]]) => void
          ): void;
        };
        analytics: {
          subscribe(callback: (data: string) => void): void;
        };
        httpError: {
          subscribe(callback: (data: string) => void): void;
        };
        requestFullscreen: {
          subscribe(callback: (data: null) => void): void;
        };
      };
    }
    export function init(options: {
      node?: HTMLElement | null;
      flags: any;
    }): Elm.Main.App;
  }
}
