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
const autoprefixer = require("gulp-autoprefixer");
const babel = require('gulp-babel');
const browsersync = require("browser-sync").create();
const cleanCSS = require("gulp-clean-css");
const del = require("del");
const exec = require('child_process').exec;
const gulp = require("gulp");
const header = require("gulp-header");
const merge = require("merge-stream");
const plumber = require("gulp-plumber");
const rename = require("gulp-rename");
const sass = require("gulp-sass");
const uglify = require("gulp-uglify");

// Load package.json for banner
const pkg = require('./package.json');

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
function clean() {
  return del(["./compiled/vendor/"]);
}

// Bring third party dependencies from node_modules into vendor directory
function modules() {
  // RISK RULES CONFIG
  var riskRules = gulp.src('../config/rules.yaml')
    .pipe(gulp.dest('./compiled/data/config'));
  // Bootstrap JS
  var bootstrapJS = gulp.src('./node_modules/bootstrap/dist/js/*')
    .pipe(gulp.dest('./compiled/vendor/bootstrap/js'));
  // Bootstrap SCSS
  var bootstrapSCSS = gulp.src('./node_modules/bootstrap/scss/**/*')
    .pipe(gulp.dest('./compiled/vendor/bootstrap/scss'));
  // Bootstrap Treeview JS/CSS
  var bootstrapTreeview = gulp.src('./node_modules/patternfly-bootstrap-treeview/dist/**/*')
    .pipe(gulp.dest('./compiled/vendor/bootstrap-treeview'));
  // Prism JS
  var prismjsJS = gulp.src('./node_modules/prismjs/components/**/*')
    .pipe(gulp.dest('./compiled/vendor/prismjs/js'));
  // Prism CSS
  var prismjsCSS = gulp.src('./node_modules/prismjs/themes/**/*')
    .pipe(gulp.dest('./compiled/vendor/prismjs/css'));
  // ChartJS
  var chartJS = gulp.src('./node_modules/chart.js/dist/*.js')
    .pipe(gulp.dest('./compiled/vendor/chart.js'));
  // Font Awesome
  var fontAwesome = gulp.src('./node_modules/@fortawesome/**/*')
    .pipe(gulp.dest('./compiled/vendor'));
  // jQuery Easing
  var jqueryEasing = gulp.src('./node_modules/jquery.easing/*.js')
    .pipe(gulp.dest('./compiled/vendor/jquery-easing'));
  // jQuery
  var jquery = gulp.src([
      './node_modules/jquery/dist/*',
      '!./node_modules/jquery/dist/core.js'
    ])
    .pipe(gulp.dest('./compiled/vendor/jquery'));
  // Stickyfill
  var stickyfillJS = gulp.src('./node_modules/stickyfilljs/dist/stickyfill.min.js')
    .pipe(gulp.dest('./compiled/vendor/stickyfilljs'));
  // vis-network  
  var visNetworkJS = gulp.src('./node_modules/vis-network/standalone/umd/*')
    .pipe(gulp.dest('./compiled/vendor/vis-network'));
  // vue.js  
  var vueJS = gulp.src('./node_modules/vue/dist/vue.min.js')
    .pipe(gulp.dest('./compiled/vendor/vue'));
  return merge(
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

// CSS task
function css() {
  return gulp
    .src([
      "./src/scss/**/*.scss"
    ])
    .pipe(plumber())
    .pipe(sass({
      outputStyle: "expanded",
      includePaths: "./node_modules",
    }))
    .on("error", sass.logError)
    .pipe(autoprefixer({
      cascade: false
    }))
    .pipe(header(banner, {
      pkg: pkg
    }))
    .pipe(gulp.dest("./compiled/css"))
    .pipe(rename({
      suffix: ".min"
    }))
    .pipe(cleanCSS())
    .pipe(gulp.dest("./compiled/css"))
    .pipe(browsersync.stream());
}

// JS task
function js() {
  return gulp
    .src([
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
    .pipe(gulp.dest('./compiled/js'))
    .pipe(browsersync.stream());
}

// Watch files
function watchFiles() {
  gulp.watch("./src/scss/**/*", css);
  gulp.watch(["./src/js/**/*", "!./src/js/**/*.min.js"], js);
  gulp.watch("./src/html/**/*.html", gulp.series(compileHtml, browserSyncReload));
}

// Compile HTML
function compileHtml() {
  return exec('node_modules/.bin/html-includes --src src/html --dest ./compiled', function (err, stdout, stderr) {
    console.log(stdout);
    console.log(stderr);
  });
}

// Define complex tasks
const vendor = gulp.series(clean, modules);
const build = gulp.series(vendor, gulp.parallel(css, js, compileHtml));
const release = gulp.series(build, gulp.parallel(compileHtml));
const watch = gulp.series(build, gulp.parallel(watchFiles, browserSync));

// Export tasks
exports.css = css;
exports.js = js;
exports.clean = clean;
exports.vendor = vendor;
exports.build = build;
exports.compileHtml = compileHtml;
exports.watch = watch;
exports.default = build;
exports.release = release;
