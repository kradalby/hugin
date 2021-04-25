// FILE DOWNLOAD

// let saveAs = require('./FileSaver.js')
// require("web-streams-polyfill");
// let StreamSaver = require("streamsaver");
//
// let JSZip = require("jszip");
// let JSZipUtils = require("jszip-utils");
//
// function urlToPromise(url: string) {
//   return new Promise(function(resolve, reject) {
//     JSZipUtils.getBinaryContent(url, function(err: Error, data: Uint8Array) {
//       if (err) {
//         reject(err);
//       } else {
//         resolve(data);
//       }
//     });
//   });
// }
//
// function downloadImages(urls: string[]) {
//   console.log("[DEBUG] Download images is called with: ", urls);
//   let zip = new JSZip();
//   const fileStream = StreamSaver.createWriteStream("download.zip");
//   const writer = fileStream.getWriter();
//
//   urls.forEach(url => {
//     let filename = url.replace(/.*\//g, "");
//     console.log(`[DEBUG] Adds file ${filename} to zip`);
//     zip.file(filename, urlToPromise(url), { binary: true });
//   });
//
//   console.log("[DEBUG] Zip: ", zip);
//
//   zip
//     .generateInternalStream({ type: "uint8array", streamFiles: true })
//     .on("data", (data: Uint8Array) => {
//       writer.write(data);
//       // writer.write(new Blob([data]))
//     })
//     .on("end", () => {
//       console.log("Reached end of zip stream");
//       writer.close();
//     })
//     .on("error", (error: Error) => {
//       console.log(error);
//       writer.abort(error);
//     })
//     .resume();
//
//   return false;
// }