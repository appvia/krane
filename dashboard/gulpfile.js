/*
Copyright 2020 Appvia Ltd <info@appvia.io>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

"use strict";

// Load plugins
import postcss from 'gulp-postcss';
import autoprefixer from "gulp-autoprefixer";
import babel from 'gulp-babel';
// const browsersync = require("browser-sync").create();
import * as bs from 'browser-sync';
const browsersync = bs.create();
import cleanCSS from "gulp-clean-css";
import { deleteAsync } from 'del';
import { exec } from 'child_process';
// import { src, dest, watch as __watch, series, parallel } from "gulp";
import { src, dest, watch, series, parallel } from "gulp";
import header from "gulp-header";
import mergeStream from "merge-stream";
import plumber from "gulp-plumber";
import rename from "gulp-rename";
// const sass = require('gulp-sass')(require('sass'));
import gulpSass from 'gulp-sass';
import * as s from 'sass';
const sass = gulpSass(s);
import uglify from "gulp-uglify";

// Load package.json for banner
import pkg from './package.json' assert { type: "json" };

// Set the banner content
const banner = ['/*!\n',
  ' * Start Bootstrap - <%= pkg.title %> v<%= pkg.version %> (<%= pkg.homepage %>)\n',
  ' * Copyright 2019-' + (new Date()).getFullYear(), ' <%= pkg.author %>\n',
  ' * Licensed under <%= pkg.license %> (https://github.com/appvia/<%= pkg.name %>/blob/master/LICENSE)\n',
  ' */\n',
  '\n'
].join('');

// BrowserSync
function browserSync(done) {
  browsersync.init({
    server: {
      baseDir: "./compiled"
    },
    port: 3000
  });
  done();
}

// BrowserSync reload
function browserSyncReload(done) {
  browsersync.reload();
  done();
}

// Clean vendor
function clean(done) {
  async () => {
    await deleteAsync('./compiled/vendor/');
  }
  done();
}

// Bring third party dependencies from node_modules into vendor directory
function modules(done) {
  async () => {
    // RISK RULES CONFIG
    var riskRules = src('../config/rules.yaml')
      .pipe(dest('./compiled/data/config'));
    // Bootstrap JS
    var bootstrapJS = src('./node_modules/bootstrap/dist/js/*')
      .pipe(dest('./compiled/vendor/bootstrap/js'));
    // Bootstrap SCSS
    var bootstrapSCSS = src('./node_modules/bootstrap/scss/**/*')
      .pipe(dest('./compiled/vendor/bootstrap/scss'));
    // Bootstrap Treeview JS/CSS
    var bootstrapTreeview = src('./node_modules/patternfly-bootstrap-treeview/dist/**/*')
      .pipe(dest('./compiled/vendor/bootstrap-treeview'));
    // Prism JS
    var prismjsJS = src('./node_modules/prismjs/components/**/*')
      .pipe(dest('./compiled/vendor/prismjs/js'));
    // Prism CSS
    var prismjsCSS = src('./node_modules/prismjs/themes/**/*')
      .pipe(dest('./compiled/vendor/prismjs/css'));
    // ChartJS
    var chartJS = src('./node_modules/chart.js/dist/*.js')
      .pipe(dest('./compiled/vendor/chart.js'));
    // Font Awesome
    var fontAwesome = src('./node_modules/@fortawesome/**/*')
      .pipe(dest('./compiled/vendor'));
    // jQuery Easing
    var jqueryEasing = src('./node_modules/jquery.easing/*.js')
      .pipe(dest('./compiled/vendor/jquery-easing'));
    // jQuery
    var jquery = src([
      './node_modules/jquery/dist/*',
      '!./node_modules/jquery/dist/core.js'
    ])
      .pipe(dest('./compiled/vendor/jquery'));
    // Stickyfill
    var stickyfillJS = src('./node_modules/stickyfilljs/dist/stickyfill.min.js')
      .pipe(dest('./compiled/vendor/stickyfilljs'));
    // vis-network
    var visNetworkJS = src('./node_modules/vis-network/standalone/umd/*')
      .pipe(dest('./compiled/vendor/vis-network'));
    // vue.js
    // var vueJS = src('./node_modules/vue/dist/vue.min.js')
    var vueJS = src('./node_modules/vue/index.js')
      .pipe(dest('./compiled/vendor/vue'));
    return mergeStream(
      bootstrapJS,
      bootstrapSCSS,
      bootstrapTreeview,
      prismjsJS,
      prismjsCSS,
      chartJS,
      fontAwesome,
      jquery,
      jqueryEasing,
      stickyfillJS,
      visNetworkJS,
      vueJS
    );
  }
  done();
}

// CSS task
function css(done) {
  async () => {
    return src([
      "./src/scss/**/*.scss"
    ])
      .pipe(plumber())
      .pipe(sass({
        outputStyle: "expanded",
        includePaths: "./node_modules",
      }))
      .on("error", sass.logError)
      .pipe(postcss([autoprefixer()]))
      // .pipe(autoprefixer({
      //   cascade: false
      // }))
      .pipe(header(banner, {
        pkg: pkg
      }))
      .pipe(dest("./compiled/css"))
      .pipe(rename({
        suffix: ".min"
      }))
      .pipe(cleanCSS())
      .pipe(dest("./compiled/css"))
      .pipe(browsersync.stream());
  }
  done();
}

// JS task
function js(done) {
  async () => {
    return src([
      './src/js/*.js',
      '!./src/js/*.min.js',
    ])
      .pipe(babel({
        presets: ['env']
      }))
      .pipe(uglify())
      .pipe(header(banner, {
        pkg: pkg
      }))
      .pipe(rename({
        suffix: '.min'
      }))
      .pipe(dest('./compiled/js'))
      .pipe(browsersync.stream());
  }
  done();
}

// Watch files
function watchFiles(done) {
  async () => {
    watch("./src/scss/**/*", css);
    watch(["./src/js/**/*", "!./src/js/**/*.min.js"], js);
    watch("./src/html/**/*.html", series(compileHtml, browserSyncReload));
  }
  done();
}

// Compile HTML
function compileHtml(done) {
  async () => {
    return exec('node_modules/.bin/html-includes --src src/html --dest ./compiled', function (err, stdout, stderr) {
      console.log(stdout);
      console.log(stderr);
    });
  }
  done();
}

// Define complex tasks
const vendor = series(clean, modules);
const build = series(vendor, parallel(css, js, compileHtml));
const release = series(build, compileHtml);
const watcher = series(build, parallel(watchFiles, browserSync));

export { clean, css, js, vendor, build, compileHtml, watcher as watch, release };

export default build;
