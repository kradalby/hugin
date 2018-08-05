// require('./styles/reset.css');
// require('materialize-css/sass/materialize.scss')
//
require('@fortawesome/fontawesome')
require('@fortawesome/fontawesome-free-solid')

require('../assets/css/custom.scss')
require('../assets/css/flexbin.scss')
require('./index.html')

require('bootstrap/js/dist/modal')

let saveAs = require('./FileSaver.js')

require('mapbox-gl/dist/mapbox-gl.css')
let mapboxgl = require('mapbox-gl')
mapboxgl.accessToken = 'pk.eyJ1Ijoia3JhZGFsYnkiLCJhIjoiY2prZ3huOHE3MDFhYjNrcXF6cHo0d2p4eSJ9.ziohBVzNJe3_miSeuFFp5g'

let JSZip = require('jszip')
let JSZipUtils = require('jszip-utils')

let Elm = require('./Main.elm')

let app = Elm.Main.fullscreen()

var map = null

function rafAsync () {
  return new Promise(resolve => {
    requestAnimationFrame(resolve) // faster than set time out
  })
}

function checkElementById (selector) {
  if (document.getElementById(selector) === null) {
    return rafAsync().then(() => checkElementById(selector))
  } else {
    return Promise.resolve(document.getElementById(selector))
  }
}

app.ports.initMap.subscribe((coordinates) => {
  initMap(coordinates)
})
// coordinates: [[-80.425, 46.437], [-71.516, 46.437]]
function initMap (coordinates) {
  console.log('initMap called with: ', coordinates)
  if (map) {
    map = null
  }

  checkElementById('map').then(() => {
    // Create map
    map = new mapboxgl.Map({
      container: 'map',
      style: 'mapbox://styles/mapbox/light-v9',
      zoom: 13,
      interactive: false,
      maxZoom: 10,
      minZoom: 2
    })

    let bounds = new mapboxgl.LngLatBounds()

    // Draw markers
    coordinates.forEach((coordinate) => {
      new mapboxgl.Marker()
        .setLngLat(coordinate)
        .addTo(map)

      bounds.extend(coordinate)
    })
    map.fitBounds(bounds, {
      padding: {top: 65, bottom: 50, left: 50, right: 50},
      linear: false,
      maxZoom: 10
    })
  })
}

// Download albums
app.ports.downloadImages.subscribe((urls) => {
  downloadImages(urls)
})

function urlToPromise (url) {
  return new Promise(function (resolve, reject) {
    JSZipUtils.getBinaryContent(url, function (err, data) {
      if (err) {
        reject(err)
      } else {
        resolve(data)
      }
    })
  })
}

// function urlToPromise (url) {
//   fetch(url) // 1) fetch the url
//     .then(function (response) { // 2) filter on 200 OK
//       console.log(response)
//       console.log(response.status)
//       if (response.status === 200 || response.status === 0) {
//         return Promise.resolve(response.blob())
//       } else {
//         return Promise.reject(new Error(response.statusText))
//       }
//     })
// }

function downloadImages (urls) {
  console.log('Download images is called with: ', urls)
  let zip = new JSZip()

  urls.forEach((url) => {
    let filename = url.replace(/.*\//g, '')
    zip.file(filename, urlToPromise(url), {binary: true})
  })

  // when everything has been downloaded, we can trigger the dl
  zip.generateAsync({type: 'blob'}, function updateCallback (metadata) {
    // Inform elm app
    app.ports.downloadProgress.send(metadata.percent.toFixed(2) | 0)
  })
    .then(function callback (blob) {
      // see FileSaver.js
      saveAs(blob, 'download.zip')
    }, function (e) {
      console.err(e)
    })

  return false
}
