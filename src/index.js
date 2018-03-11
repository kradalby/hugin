// require('./styles/reset.css');
// require('materialize-css/sass/materialize.scss')
//
require('bootstrap/scss/bootstrap.scss')
require('../assets/css/sticky-footer.css')
require('../assets/css/logo.css')
require('../assets/css/override.scss')
require('../assets/css/flexbin.scss')
require('./index.html')

var Elm = require('./Main.elm')
var mountNode = document.getElementById('root')

var app = Elm.Main.embed(mountNode)
