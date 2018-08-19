const path = require('path')
const CopyWebpackPlugin = require('copy-webpack-plugin')
const MinifyPlugin = require('babel-minify-webpack-plugin')

const elmLoaders = process.env.NODE_ENV === 'development' ? [
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
        use: elmLoaders
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

  plugins: process.env.NODE_ENV === 'development' ? [] : [
    new CopyWebpackPlugin([
      { from: 'assets/images', to: 'assets/images' }
    ]),
    new MinifyPlugin({}, {})
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
