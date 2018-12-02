let Elm = require('./Main.elm')
let app = Elm.Main.fullscreen()

// require('./styles/reset.css');
// require('materialize-css/sass/materialize.scss')

// FONT AWESOME
require('@fortawesome/fontawesome')
require('@fortawesome/fontawesome-free-solid')

// SCSS
require('../assets/css/custom.scss')
require('../assets/css/flexbin.scss')

// BOOTSTRAP
require('bootstrap/js/dist/modal')

// Helper functions
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

// Google Analytics
app.ports.analytics.subscribe((url) => {
  console.log('DEBUG: gtag called with: ', url)
  gtag('config', 'UA-18856525-25', {'page_path': '/' + url})
})

// MAPBOX
require('mapbox-gl/dist/mapbox-gl.css')
let mapboxgl = require('mapbox-gl')
mapboxgl.accessToken = MAPBOX_ACCESS_TOKEN

var map = null

app.ports.initMap.subscribe((data) => {
  initMap(data)
})

// coordinates: [Name : String, [[-80.425, 46.437], [-71.516, 46.437]] : List ( Float, Float ) ]
function initMap (data) {
  console.log('DEBUG: initMap called with: ', data)

  // ----------------------------------------------
  // Clean up maps and old maps
  //

  // Try to force some garbage collection
  if (map) {
    map.remove()
    map = null
  }

  // Ugly hack to remove not garbage collected rouge maps
  document.querySelectorAll('[class^=mapboxgl]').forEach(
    (element) => {
      element.parentNode.removeChild(element)
    })

  // ----------------------------------------------

  let divName = 'map-' + data[0]
  let coordinates = data[1]

  checkElementById(divName).then(() => {
    // Create map
    map = new mapboxgl.Map({
      container: divName,
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

// FILE DOWNLOAD

// let saveAs = require('./FileSaver.js')
require('web-streams-polyfill')
let StreamSaver = require('streamsaver')

let JSZip = require('jszip')
let JSZipUtils = require('jszip-utils')

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

function downloadImages (urls) {
  console.log('Download images is called with: ', urls)
  let zip = new JSZip()
  const fileStream = StreamSaver.createWriteStream('download.zip')
  const writer = fileStream.getWriter()

  urls.forEach((url) => {
    let filename = url.replace(/.*\//g, '')
    zip.file(filename, urlToPromise(url), {binary: true})
  })

  zip.generateInternalStream({type: 'uint8array', streamFiles: true})
    .on('data', data => {
      writer.write(data)
      // writer.write(new Blob([data]))
    })
    .on('end', () => {
      console.log('Reached end of zip stream')
      writer.close()
    })
    .on('error', error => {
      console.err(error)
      writer.abort(error)
    }).resume()

  return false
}
