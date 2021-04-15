const path = require("path");
const webpack = require("webpack");

const MinifyPlugin = require("babel-minify-webpack-plugin");
const HTMLWebpackPlugin = require("html-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const OptimizeCssAssetsPlugin = require("optimize-css-assets-webpack-plugin");
const SizePlugin = require("size-plugin");

const mode = process.env.NODE_ENV || "development";
const production = mode === "production";
console.log(mode);

module.exports = {
  mode: mode,
  entry: "./src/index.ts",
  output: {
    path: path.join(__dirname, "dist"),
    filename: production ? "[name]-[hash].js" : "index.js",
  },
  resolve: {
    modules: [path.join(__dirname, "src"), "node_modules"],
    extensions: [".js", ".elm", ".scss", ".ts"],
  },
  plugins: [
    new webpack.DefinePlugin({
      MAPBOX_ACCESS_TOKEN: JSON.stringify(
        process.env.HUGIN_MAPBOX_ACCESS_TOKEN
      ),
      SENTRY_DSN: JSON.stringify(process.env.HUGIN_SENTRY_DSN),
      ROLLBAR_ACCESS_TOKEN: JSON.stringify(
        process.env.HUGIN_ROLLBAR_ACCESS_TOKEN
      ),
    }),
    new SizePlugin(),
    new HTMLWebpackPlugin({
      template: "src/index.html",
      inject: "body",
    }),
    new MiniCssExtractPlugin({
      filename: "[name]-[hash].css",
      chunkFilename: "[id].[hash].css",
    }),
  ],
  module: {
    rules: [
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: [
          {
            loader: "elm-hot-webpack-loader",
          },
          {
            loader: "elm-webpack-loader",
            options: {
              debug: !production,
              verbose: !production,
              optimize: production,
            },
          },
        ],
      },
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
        },
      },
      { test: /\.ts$/, loader: "ts-loader" },
      {
        test: /\.scss$/,
        loaders: [
          production ? MiniCssExtractPlugin.loader : "style-loader",
          "css-loader",
          "sass-loader",
        ],
      },
      {
        test: /\.css$/,
        loaders: [
          production ? MiniCssExtractPlugin.loader : "style-loader",
          "css-loader",
        ],
      },

      {
        test: /\.(png|jpg|gif|svg|eot|ttf|woff|woff2)$/,
        use: [
          {
            loader: "file-loader",
            options: {
              name: "[name].[ext]",
            },
          },
        ],
      },
    ],
  },
  optimization: {
    splitChunks: {
      chunks: "all",
    },
    minimizer: [
      new MinifyPlugin({ builtIns: false }, {}), // Option so MapBox minify will work
      new OptimizeCssAssetsPlugin({}),
    ],
  },
  devServer: {
    proxy: {
      "/content": {
        // target: "http://localhost:3000",
        target: "http://10.60.0.44:3000",
        pathRewrite: { "^/content": "" },
      },
    },
    inline: true,
    stats: { colors: true },
    disableHostCheck: true,
  },
};

//       // Suggested for hot-loading
//       new webpack.NamedModulesPlugin(),
//       // Prevents compilation errors causing the hot loader to lose state
//       new webpack.NoEmitOnErrorsPlugin()
