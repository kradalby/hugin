const path = require("path");
const webpack = require("webpack");
const merge = require("webpack-merge");

const history = require("koa-connect-history-api-fallback");
const convert = require("koa-connect");
const proxy = require("http-proxy-middleware");

const CopyWebpackPlugin = require("copy-webpack-plugin");
const MinifyPlugin = require("babel-minify-webpack-plugin");
// const CleanWebpackPlugin = require('clean-webpack-plugin')
const HTMLWebpackPlugin = require("html-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const OptimizeCssAssetsPlugin = require("optimize-css-assets-webpack-plugin");
const SizePlugin = require("size-plugin");
// const CompressionPlugin = require('compression-webpack-plugin')

const mode = process.env.NODE_ENV || "development";
const production = mode === "production";
console.log(mode);

var common = {
  mode: mode,
  entry: "./src/index.js",
  output: {
    path: path.join(__dirname, "dist"),
    filename: production ? "[name]-[hash].js" : "index.js"
  },
  plugins: [
    new webpack.DefinePlugin({
      MAPBOX_ACCESS_TOKEN: JSON.stringify(process.env.MAPBOX_ACCESS_TOKEN)
    }),
    new SizePlugin(),
    new HTMLWebpackPlugin({
      template: "src/index.html",
      inject: "body"
    }),
    new MiniCssExtractPlugin({
      filename: "[name]-[hash].css",
      chunkFileName: "[id].[hash].css"
    })
  ],
  resolve: {
    modules: [path.join(__dirname, "src"), "node_modules"],
    extensions: [".js", ".elm", ".scss", ".png"]
  },
  module: {
    rules: [
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: [
          {
            loader: "elm-hot-webpack-loader"
          },
          {
            loader: "elm-webpack-loader",
            options: {
              debug: !production,
              verbose: !production
            }
          }
        ]
      },
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader"
        }
      },
      {
        test: /\.scss$/,
        loaders: [
          production ? MiniCssExtractPlugin.loader : "style-loader",
          "css-loader",
          "sass-loader"
        ]
      },
      {
        test: /\.css$/,
        loaders: [
          production ? MiniCssExtractPlugin.loader : "style-loader",
          "css-loader"
        ]
      },

      {
        test: /\.(png|jpg|gif|svg|eot|ttf|woff|woff2)$/,
        loader: "url-loader",
        options: {
          limit: 10000
        }
      }
    ]
  },
  optimization: {
    splitChunks: {
      chunks: "all"
    },
    minimizer: [
      new MinifyPlugin({ builtIns: false }, {}), // Option so MapBox minify will work
      new OptimizeCssAssetsPlugin({})
      // new CompressionPlugin({})
    ]
  },
  devServer: {
    proxy: {
      "/content": {
        target: "http://localhost:3000",
        pathRewrite: { "^/content": "" }
      }
    },
    inline: true,
    stats: { colors: true },
    disableHostCheck: true
  }
};

if (mode === "development") {
  console.log("Building for dev...");
  module.exports = merge(common, {
    plugins: [
      // Suggested for hot-loading
      new webpack.NamedModulesPlugin(),
      // Prevents compilation errors causing the hot loader to lose state
      new webpack.NoEmitOnErrorsPlugin()
    ],
    module: {
      rules: []
    }
  });
}

if (mode === "production") {
  console.log("Building for Production...");
  module.exports = merge(common, {
    plugins: [
      // Delete everything from output directory and report to user
      // new CleanWebpackPlugin({
      //   root: __dirname,
      //   exclude: [],
      //   verbose: true,
      //   dry: false
      // }),
      new CopyWebpackPlugin([
        {
          from: "assets/images",
          to: "assets/images"
        }
      ])
    ]
    // module: {
    //   rules: [
    //     {
    //       test: /\.css$/,
    //       exclude: [/elm-stuff/, /node_modules/],
    //       loaders: [MiniCssExtractPlugin.loader, "css-loader"]
    //     },
    //     {
    //       test: /\.scss$/,
    //       // exclude: [/elm-stuff/, /node_modules/],
    //       loaders: [MiniCssExtractPlugin.loader, "css-loader", "sass-loader"]
    //     }
    //   ]
    // }
  });
}
