const path = require('path')
const webpack = require('webpack')

const history = require('koa-connect-history-api-fallback')
const convert = require('koa-connect')
const proxy = require('http-proxy-middleware')

const CopyWebpackPlugin = require('copy-webpack-plugin')
const MinifyPlugin = require('babel-minify-webpack-plugin')
const CleanWebpackPlugin = require('clean-webpack-plugin')

const mode = process.env.NODE_ENV

module.exports = {
  mode: mode || 'development',
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
        use: mode === 'development' ? [
          { loader: 'elm-hot-loader' },
          {
            loader: 'elm-webpack-loader',
            options: {
              debug: true,
              verbose: true,
              warn: true
            }
          }
        ] : [
          { loader: 'elm-webpack-loader' }
        ]
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

  plugins: process.env.NODE_ENV === 'development' ? [
    // Suggested for hot-loading
    new webpack.NamedModulesPlugin(),
    // Prevents compilation errors causing the hot loader to lose state
    new webpack.NoEmitOnErrorsPlugin()
  ] : [
    // Delete everything from output directory and report to user
    new CleanWebpackPlugin(['dist'], {
      root: __dirname,
      exclude: [],
      verbose: true,
      dry: false
    }),
    new CopyWebpackPlugin([
      { from: 'assets/images' }
    ]),
    new MinifyPlugin({}, {})
  ],

  serve: {
    inline: true,
    stats: 'errors-only',
    content: [path.join(__dirname, 'src/assets')],
    add: (app, middleware, options) => {
      // routes /xyz -> /index.html
      app.use(history())
      app.use(convert(proxy('/content', { target: 'http://localhost:3000', pathRewrite: {'^/content': ''} })))
    }
  },

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
