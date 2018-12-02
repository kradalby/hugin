const path = require('path')
const webpack = require('webpack')
const merge = require('webpack-merge')

const history = require('koa-connect-history-api-fallback')
const convert = require('koa-connect')
const proxy = require('http-proxy-middleware')

const CopyWebpackPlugin = require('copy-webpack-plugin')
const MinifyPlugin = require('babel-minify-webpack-plugin')
const CleanWebpackPlugin = require('clean-webpack-plugin')
const HTMLWebpackPlugin = require('html-webpack-plugin')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const OptimizeCssAssetsPlugin = require('optimize-css-assets-webpack-plugin')
const SizePlugin = require('size-plugin')
// const CompressionPlugin = require('compression-webpack-plugin')

const mode = process.env.NODE_ENV || 'development'
const filename = mode === 'production' ? '[name]-[hash].js' : 'index.js'
console.log(mode)

var common = {
  mode: mode,
  entry: './src/index.js',
  output: {
    path: path.join(__dirname, 'dist'),
    // webpack -p automatically adds hash when building for production
    filename: filename
  },
  plugins: [
    new webpack.DefinePlugin({
      MAPBOX_ACCESS_TOKEN: JSON.stringify(process.env.MAPBOX_ACCESS_TOKEN)
    }),
    new SizePlugin(),
    new HTMLWebpackPlugin({
      // Use this template to get basic responsive meta tags
      template: 'src/index.html',
      // inject details of output file at end of body
      inject: 'body'
    })
  ],
  resolve: {
    modules: [path.join(__dirname, 'src'), 'node_modules'],
    extensions: ['.js', '.elm', '.scss', '.png']
  },
  module: {
    noParse: /(mapbox-gl)\.js$/,
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      },
      {
        test: /\.scss$/,
        // exclude: [/elm-stuff/, /node_modules/],
        loaders: ['style-loader', 'css-loader', 'sass-loader']
      },
      {
        test: /\.css$/,
        // exclude: [/elm-stuff/, /node_modules/],
        loaders: ['style-loader', 'css-loader']
      },

      {
        test: /\.(png|jpg|gif|svg|eot|ttf|woff|woff2)$/,
        loader: 'url-loader',
        options: {
          limit: 10000
        }
      }
    ]
  },
  optimization: {
    splitChunks: {
      chunks: 'all'
    },
    minimizer: [
      new MinifyPlugin({}, {}),
      new OptimizeCssAssetsPlugin({})
      // new CompressionPlugin({})
    ]
  }
}

if (mode === 'development') {
  console.log('Building for dev...')
  module.exports = merge(common, {
    plugins: [
      // Suggested for hot-loading
      new webpack.NamedModulesPlugin(),
      // Prevents compilation errors causing the hot loader to lose state
      new webpack.NoEmitOnErrorsPlugin()
    ],
    module: {
      rules: [
        {
          test: /\.elm$/,
          exclude: [/elm-stuff/, /node_modules/],
          use: [
            {
              loader: 'elm-hot-loader'
            },
            {
              loader: 'elm-webpack-loader',
              // add Elm's debug overlay to output
              options: {
                debug: true,
                verbose: true,
                warn: true
              }
            }
          ]
        }
      ]
    },
    serve: {
      inline: true,
      stats: 'errors-only',
      content: [path.join(__dirname, '')],
      add: (app, middleware, options) => {
        // routes /xyz -> /index.html
        app.use(history())
        app.use(
          convert(
            proxy(
              '/content',
              {
                target: 'http://localhost:3000',
                pathRewrite: {'^/content': ''}
              }
            )
          )
        )
      }
    }
  })
}

if (mode === 'production') {
  console.log('Building for Production...')
  module.exports = merge(common, {
    plugins: [
      // Delete everything from output directory and report to user
      new CleanWebpackPlugin(['dist'], {
        root: __dirname,
        exclude: [],
        verbose: true,
        dry: false
      }),
      new CopyWebpackPlugin([
        {
          from: 'assets/images',
          to: 'assets/images'
        }
      ]),
      new MiniCssExtractPlugin({
        // Options similar to the same options in webpackOptions.output
        // both options are optional
        filename: '[name]-[hash].css',
        chunkFileName: '[id].[hash].css'
      })
    ],
    module: {
      rules: [
        {
          test: /\.elm$/,
          exclude: [/elm-stuff/, /node_modules/],
          use: [
            {
              loader: 'elm-webpack-loader'
            }
          ]
        },
        {
          test: /\.css$/,
          exclude: [/elm-stuff/, /node_modules/],
          loaders: [
            MiniCssExtractPlugin.loader,
            'css-loader'
          ]
        },
        {
          test: /\.scss$/,
          // exclude: [/elm-stuff/, /node_modules/],
          loaders: [
            MiniCssExtractPlugin.loader,
            'css-loader',
            'sass-loader'
          ]
        }
      ]
    }
  })
}
