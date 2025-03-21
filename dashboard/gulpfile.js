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
import nodemon from 'nodemon';
import babel from 'gulp-babel';
import cleanCSS from "gulp-clean-css";
import { deleteAsync } from 'del';
import { exec } from 'child_process';
import { src, dest, watch, series, parallel } from "gulp";
import header from "gulp-header";
import plumber from "gulp-plumber";
import rename from "gulp-rename";
import gulpSass from 'gulp-sass';
import * as s from 'sass';
const sass = gulpSass(s);
import uglify from "gulp-uglify";

// Load package.json for banner
import pkg from './package.json' assert { type: "json" };

// Set the banner content
const banner = ['/*!\n',
  ' * <%= pkg.title %> v<%= pkg.version %> (<%= pkg.homepage %>)\n',
  ' * Copyright 2019-' + (new Date()).getFullYear(), ' <%= pkg.author %>\n',
  ' * Licensed under <%= pkg.license %> (https://github.com/appvia/<%= pkg.name %>/blob/master/LICENSE)\n',
  ' */\n',
  '\n'
].join('');

// Clean vendor
function clean() {
  return new Promise((done) => {
    deleteAsync('./compiled/vendor/');
    done();
  });
}

// ==== vendor ====

// Risk Rules Config
function riskRules() {
  return new Promise((done) => {
    src('../config/rules.yaml')
      .pipe(dest('./compiled/data/config'))
      .on('end', done);
  });
}

// Bootstrap JS
function bootstrapJS() {
  return new Promise((done) => {
    src('./node_modules/bootstrap/dist/js/*')
      .pipe(dest('./compiled/vendor/bootstrap/js'))
      .on('end', done);
  });
}

export { bootstrapJS };

// Bootstrap SCSS
function bootstrapSCSS() {
  return new Promise((done) => {
    src('./node_modules/bootstrap/scss/**/*')
      .pipe(dest('./compiled/vendor/bootstrap/scss'))
      .on('end', done);
  });
}

export { bootstrapSCSS };

// Bootstrap Treeview JS/CSS
function bootstrapTreeview() {
  return new Promise((done) => {
    src('./node_modules/patternfly-bootstrap-treeview/dist/**/*')
      .pipe(dest('./compiled/vendor/bootstrap-treeview'))
      .on('end', done);
  });
}

// Prism JS
function prismjsJS() {
  return new Promise((done) => {
    src('./node_modules/prismjs/components/**/*')
      .pipe(dest('./compiled/vendor/prismjs/js'))
      .on('end', done);
  });
}

// Prism CSS
function prismjsCSS() {
  return new Promise((done) => {
    src('./node_modules/prismjs/themes/**/*')
      .pipe(dest('./compiled/vendor/prismjs/css'))
      .on('end', done);
  });
}

// ChartJS
function chartJS() {
  return new Promise((done) => {
    src('./node_modules/chart.js/dist/*.js')
      .pipe(dest('./compiled/vendor/chart.js'))
      .on('end', done);
  });
}

// Font Awesome
function fontAwesome() {
  return new Promise((done) => {
    src('./node_modules/@fortawesome/**/*')
      .pipe(dest('./compiled/vendor'))
      .on('end', done);
  });
}

// jQuery Easing
function jqueryEasing() {
  return new Promise((done) => {
    src('./node_modules/jquery.easing/*.js')
      .pipe(dest('./compiled/vendor/jquery-easing'))
      .on('end', done);
  });
}

// jQuery
function jquery() {
  return new Promise((done) => {
    src([
      './node_modules/jquery/dist/*',
      '!./node_modules/jquery/dist/core.js'
    ])
      .pipe(dest('./compiled/vendor/jquery'))
      .on('end', done);
  });
}

// Stickyfill
function stickyfillJS() {
  return new Promise((done) => {
    src('./node_modules/stickyfilljs/dist/stickyfill.min.js')
      .pipe(dest('./compiled/vendor/stickyfilljs'))
      .on('end', done);
  });
}

// vis-network
function visNetworkJS() {
  return new Promise((done) => {
    src('./node_modules/vis-network/standalone/umd/*')
      .pipe(dest('./compiled/vendor/vis-network'))
      .on('end', done);
  });
}

// vue.js
function vueJS() {
  return new Promise((done) => {
    src('./node_modules/vue/dist/vue.global.*')
      .pipe(dest('./compiled/vendor/vue'))
      .on('end', done);
  });
}

// Bring third party dependencies from node_modules into vendor directory
function modules() {
  return Promise.all([
    riskRules(), // RISK RULES CONFIG
    bootstrapJS(),
    bootstrapSCSS(),
    bootstrapTreeview(),
    prismjsJS(),
    prismjsCSS(),
    chartJS(),
    fontAwesome(),
    jquery(),
    jqueryEasing(),
    stickyfillJS(),
    visNetworkJS(),
    vueJS()
  ]);
}

// CSS task
function css() {

  return src([
    "./src/scss/**/*.scss"
  ])
    .pipe(plumber({
      errorHandler: function (err) {
        console.error('Error!', err.message); // Log errors
        this.emit('end'); // Prevent Gulp from crashing
      }
    }))
    .pipe(sass({
      outputStyle: "expanded",
      includePaths: "./node_modules",
    }))
    .on("error", sass.logError)
    .pipe(header(banner, {
      pkg: pkg
    }))
    .pipe(dest("./compiled/css"))
    .pipe(rename({
      suffix: ".min"
    }))
    .pipe(cleanCSS())
    .pipe(dest("./compiled/css"))
}

// JS task
function js() {
  return src([
    './src/js/*.js',
    '!./src/js/*.min.js',
  ])
    .pipe(plumber())
    .pipe(babel({
      presets: ['@babel/preset-env']
    }))
    .pipe(uglify())
    .pipe(header(banner, {
      pkg: pkg
    }))
    .pipe(rename({
      suffix: '.min'
    }))
    .pipe(dest('./compiled/js'));
}

// Watch files
function watchFiles(done) {
  async () => {
    watch("./src/scss/**/*", css);
    watch(["./src/js/**/*", "!./src/js/**/*.min.js"], js);
    watch("./src/html/**/*.html", compileHtml);
  }
  done();
}

// Compile HTML
function compileHtml(done) {
  return new Promise((done) => {
    return exec('bundle exec jekyll build -s src/html -d ./tmp && cp ./tmp/*.html ./compiled && rm -rf ./tmp', function (err, stdout, stderr) {
      console.log(stdout);
      console.log(stderr);
      done();
    });
  });
}


function develop(done) {
  var stream = nodemon({
    script: './dashboard.js',
    watch: ['./src'], // watch source changes
    ext: 'html js css yaml json', // watched files extensions
    done: done
  })

  stream
    .on('restart', function () {
      // rebuild js, css and html
      js();
      css();
      compileHtml();

      console.log('---------')
      console.log('- Changes detected and application restarted! Refresh your browser to see changes.')
      console.log('---------')
    })
    .on('crash', function () {
      console.error('Application has crashed!\n')
      stream.emit('restart', 10)  // restart the server in 10 seconds
    })
}

// Define complex tasks
const vendor = series(clean, modules);
const build = series(vendor, parallel(css, js));
const release = series(build, compileHtml);
const watcher = series(release, develop);

export { clean, css, js, vendor, build, compileHtml, watcher as watch, release };

export default build;
