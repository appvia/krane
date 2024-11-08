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

$(function () {

  // Load RBAC tree
  $.getJSON("data/" + $.urlParam('cluster') + "/rbac-tree.json", function (rbac) {

    // Rule description box always visible
    Stickyfill.addOne($('.sticky'));
    Stickyfill.forceSticky();

    // Searchable treeview
    const $searchableTree = $('#treeview-searchable').treeview({
      data: [rbac],
      expandIcon: 'fas fa-chevron-right',
      collapseIcon: 'fas fa-chevron-down',
      showTags: true,
      showBorder: true,
      onRendered: function (event, nodes) {
        // when search term in query string initiate search
        const term = $.urlParam('term');
        if (term && $searchableTree) {
          $('#input-search').val(term);
          $('#chk-ignore-case').attr('checked', true);
          $('#chk-exact-match').attr('checked', true);
          $('#chk-reveal-results').attr('checked', true);
          search();
        }
      },
      onNodeSelected: function (event, data) {
        var buffer = [data];
        var parentId = data.parentId;
        var hasChildren = data.nodes;

        if (hasChildren === null) {

          while (parentId !== '0.0') {
            var parentNode = $('#treeview-searchable').treeview('getNodes').find(n => n.nodeId === parentId);

            parentId = parentNode.parentId;
            if (parentId !== '0.0') {
              buffer.unshift(parentNode);
            }
          }

          var prevText = '';
          var d = [];

          $.map(buffer, function (val, i) {
            if (val.tags && val.tags[0] != prevText) {
              d.push(val.tags[0]);
            }

            if (buffer[i + 1] && val.text == buffer[i + 1].tags[0]) {
              d.push(val.text);
            } else {
              var dataTag = val.tags ? val.tags[0] : '';
              var tooltipActive = val.resource_kind ? 'tooltip' : '';
              var resource = val.resource_kind ? val.resource_kind.toLowerCase() : '';
              d.push(`<a data-toggle="${tooltipActive}" data-placement="bottom" data-original-title="Go to ${resource} ${val.text}"
                        class="badge bg-secondary rule-component" data-branch="${val.branch}" data-tag="${dataTag}"
                        data-resource-kind="${val.resource_kind}">` + val.text + '</a>');
            }

            prevText = val.text;
          });

          $('#rule-description').html(d.join(' '));
          $('[data-toggle="tooltip"]').tooltip();

        } else {
          $('#rule-description').html('Please navigate to the leaf node in the tree on the right hand side.');
        }

        function findNode(nodes, text, resourceKind) {
          // console.log('Searching for ' + text + ' in branch matching resource kind ' + resourceKind);
          return $.grep(nodes, function (n) {
            return n['navigable'] === true && n['text'] === text && n['branch'] === resourceKind;
          });
        };

        // Generate Rule description
        $('a.rule-component').click(function () {
          var selectedText = this.text;
          var selectedResourceKind = this.dataset.resourceKind;

          if (selectedResourceKind === 'undefined') {
            return;
          }

          var allNodes = $.merge($searchableTree.treeview('getUnselected'), $searchableTree.treeview('getSelected'));

          var found = findNode(allNodes, selectedText, selectedResourceKind);

          if (!$.isEmptyObject(found)) {
            $searchableTree.treeview('collapseAll', { silent: true });
            $searchableTree.treeview('revealNode', found, { silent: true });
            $searchableTree.treeview('selectNode', found, { silent: true });
            $('html, body').animate({
              scrollTop: ($('li.node-selected').offset().top)
            }, 200);
          } else {
            console.log('node ID not found!');
          }

        });
      },
    });

    // Tree search
    const search = function (e) {
      var pattern = $('#input-search').val();
      var options = {
        ignoreCase: $('#chk-ignore-case').is(':checked'),
        exactMatch: $('#chk-exact-match').is(':checked'),
        revealResults: $('#chk-reveal-results').is(':checked'),
      };
      var results = $searchableTree.treeview('search', [pattern, options]);
    }

    $('#btn-search').on('click', search);

    $('#btn-clear-search').on('click', function (e) {
      $searchableTree.treeview('clearSearch');
      $searchableTree.treeview('collapseAll', { silent: true });
      $searchableTree.treeview('expandAll', { levels: 1, silent: true });
      $('#input-search').val('');
      $('#rule-description').html('Nothing selected. Please select a node in the tree on the right hand side.');
    });
  });

});
