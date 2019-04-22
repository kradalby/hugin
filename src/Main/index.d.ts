// WARNING: Do not manually modify this file. It was generated using:
// https://github.com/dillonkearns/elm-typescript-interop
// Type definitions for Elm ports

export namespace Elm {
  namespace Main {
    export interface App {
      ports: {
        storeSession: {
          subscribe(callback: (data: string | null) => void): void
        }
        onSessionChange: {
          send(data: unknown): void
        }
        downloadImages: {
          subscribe(callback: (data: string[]) => void): void
        }
        initMap: {
          subscribe(callback: (data: [string, [number, number][]]) => void): void
        }
        analytics: {
          subscribe(callback: (data: string) => void): void
        }
      };
    }
    export function init(options: {
      node?: HTMLElement | null;
      flags: any;
    }): Elm.Main.App;
  }
}