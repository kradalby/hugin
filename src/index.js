// require('./styles/reset.css');
// require('materialize-css/sass/materialize.scss')
//
require('@fortawesome/fontawesome')
require('@fortawesome/fontawesome-free-solid')

require('../assets/css/custom.scss')
require('../assets/css/flexbin.scss')
require('./index.html')

var Elm = require('./Main.elm')
var mountNode = document.getElementById('root')

var app = Elm.Main.embed(mountNode)
