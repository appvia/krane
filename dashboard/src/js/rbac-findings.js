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

$(function() {

  // Load RBAC findings
  $.getJSON("data/" + $.urlParam('cluster') + "/rbac-findings.json", function(findings) {

    // findings
    new Vue({
      el: '#findings',
      data: {
        items: findings['results'],
      },
      methods: {
        filteredList: function(status) {
          return this.items.filter(item => {
            return item.status === status
          })
        }
      }
    });

    // alert dangers
    new Vue({
      el: '#alert-danger',
      data: {
        items: findings['results'].filter(item => {
          return item.status === "danger"
        })
      }
    });

    $.each(findings['summary'], function(key, value) {
      $(`#${key}-count`).html(value);
    });

    $('[data-toggle="tooltip"]').tooltip();

    // Pie Chart
    var ctx = $('#scanPieChart');
    if (ctx.length) {
      // Set new default font family and font color to mimic Bootstrap's default styling
      Chart.defaults.font.family = 'Nunito', '-apple-system,system-ui,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,sans-serif';
      Chart.defaults.color = '#858796';

      new Chart(ctx, {
        type: 'doughnut',
        data: {
          datasets: [{
            data: [
              findings['summary']['danger'],
              findings['summary']['warning'],
              findings['summary']['info'],
              findings['summary']['success']
            ],
            backgroundColor: ['#e74a3b', '#f6c23e', '#36b9cc', '#1cc88a'],
            hoverBackgroundColor: ['#c64a3b', '#d5c23e', '#05b9cc', '#0bc88a'],
            hoverBorderColor: "rgba(234, 236, 244, 1)",
          }],
        },
        options: {
          maintainAspectRatio: false,
          tooltips: {
            backgroundColor: "rgb(255,255,255)",
            bodyFontColor: "#858796",
            borderColor: '#dddfeb',
            borderWidth: 1,
            xPadding: 15,
            yPadding: 15,
            displayColors: false,
            caretPadding: 10,
          },
          legend: {
            display: false
          },
          cutoutPercentage: 70,
        },
      });
    }

  });

});
