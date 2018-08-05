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

let JSZip = require('jszip')
let JSZipUtils = require('jszip-utils')

let Elm = require('./Main.elm')

let app = Elm.Main.fullscreen()

app.ports.downloadImages.subscribe(function (urls) {
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
