const path = require('path')
const webpack = require('webpack')
const CopyWebpackPlugin = require('copy-webpack-plugin')
const BowerResolvePlugin = require('bower-resolve-webpack-plugin')

const elmLoader = process.env.NODE_ENV === 'development' ? 'elm-hot-loader!elm-webpack-loader?verbose=true&warn=true&debug=true' : 'elm-webpack-loader'

module.exports = {
  entry: {
    app: [
      './src/index.js'
    ]
  },

  output: {
    path: path.resolve(path.join(__dirname, '/dist')),
    filename: '[name].js'
  },

  module: {
    rules: [
      {
        test: /\.(css|scss)$/,
        loaders: [
          'style-loader', 'css-loader', 'sass-loader'
        ]
      },
      {
        test: /\.html$/,
        exclude: /node_modules/,
        loader: 'file-loader?name=[name].[ext]'
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader: elmLoader
      },
      {
        test: /\.(png|jpg|gif|svg|eot|ttf|woff|woff2)$/,
        loader: 'url-loader',
        options: {
          limit: 10000
        }
      }
    ],

    noParse: /\.elm$/
  },

  resolve: {
    plugins: [new BowerResolvePlugin()],
    modules: ['bower_components', 'node_modules'],
    descriptionFiles: ['bower.json', 'package.json'],
    mainFields: ['browser', 'main']
  },

  plugins: process.env.NODE_ENV === 'development' ? [] : [
    new CopyWebpackPlugin([
        { from: 'assets/images', to: 'assets/images' }
    ]),
    new webpack.optimize.UglifyJsPlugin({
      compress: {
        warnings: false
      }
    })
  ],

  devServer: {
    proxy: {
      '/content': {
        target: 'http://localhost:3000/',
        pathRewrite: {'^/content': ''}
      }
    },
    inline: true,
    stats: { colors: true },
    disableHostCheck: true
  }
}
