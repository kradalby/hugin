// MAPBOX
import mapboxgl from "mapbox-gl";

async function setMapboxToken() {
  const response = await fetch(
    "/tokens"
  );

  let body = await response.json()

  mapboxgl.accessToken = body.mapbox
}


let map: mapboxgl.Map | null = null;

// coordinates: [Name : String, [[-80.425, 46.437], [-71.516, 46.437]] : List ( Float, Float ) ]
export default async function initMap(data: [string, [number, number][]]) {
  console.log("DEBUG: initMap called with: ", data);

  if (mapboxgl.accessToken === null) {
    await setMapboxToken()
  }

  // ----------------------------------------------
  // Clean up maps and old maps
  //

  // Try to force some garbage collection
  if (map) {
    map.remove();
    map = null;
  }

  // Ugly hack to remove not garbage collected rouge maps
  document.querySelectorAll("[class^=mapboxgl]").forEach((element) => {
    if (element.parentNode !== null) {
      element.parentNode.removeChild(element);
    }
  });

  // ----------------------------------------------

  let divName = "map-" + data[0];
  let coordinates = data[1];

  await resolveElementById(divName)

  // Create map
  map = new mapboxgl.Map({
    container: divName,
    style: "mapbox://styles/mapbox/light-v9",
    zoom: 13,
    interactive: false,
    maxZoom: 10,
    minZoom: 2,
  });

  let bounds = new mapboxgl.LngLatBounds();

  // Draw markers
  coordinates.forEach((coordinate) => {
    new mapboxgl.Marker().setLngLat(coordinate).addTo(map);

    bounds.extend(coordinate);
  });
  if (map) {
    map.fitBounds(bounds, {
      padding: { top: 65, bottom: 50, left: 50, right: 50 },
      linear: false,
      maxZoom: 10,
    });
  }
}

async function resolveElementById(selector: string): Promise<HTMLElement> {
  let element = document.getElementById(selector);
  if (element === null) {
    return new Promise((resolve) => {
      requestAnimationFrame(resolve);
    }).then(() => resolveElementById(selector));
  } else {
    return Promise.resolve(element);
  }
}
