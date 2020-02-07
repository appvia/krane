# Copyright 2020 Appvia Ltd <info@appvia.io>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Understands how to build Kubernetes RBAC risk report 
# It also generates assets for UI to consume:
#  - RBAC facets data for the Tree view
#  - RBAC gtaph data for Network view

require 'active_support/core_ext/hash/indifferent_access'

module Krane
  module Report
    class Builder
      include Helpers
      extend Memoist

      attr_reader :summary, :findings

      # New report builder instance
      #
      # @param options [Options] command line options
      #
      # @return [nil]
      def initialize options
        @options   = options
        @cluster   = get_cluster_slug
        @graph     = get_graph_client
        @risk      = Config::Risk.new
        @whitelist = Config::Whitelist.new
        @resolver  = RiskRule::Resolver.new(
                        cluster:   @cluster, 
                        risk:      @risk,
                        whitelist: @whitelist
                      )
        @findings  = []          # collection of risk evaluation results
        @summary   = Hash.new(0) # summary maps risk severity kind to number of alerts for respective severity
      end

      # Builds the report
      #
      # @return [self]
      def build        
        @ingest = ingest_rbac

        if @options.noindex
          # RBAC was just cached locally but not indexed
          banner :info, '--noidex flag was used which means RBAC was cached locally but not indexed in the Graph. Further analysis will not be performed.'
          return
        end

        unless @options.ci # skip builders in CI
          build_rbac_network_view
          build_rbac_tree_view
        end

        ingest_time_findings

        @resolver.risk_rules.each { |item| finding item }

        sort_findings

        run_hooks unless @options.ci

        self
      end

      # Returns combined report map (summary + results)
      #
      # @return [Hash]
      memoize def combined
        {
          summary: @summary,
          results: @findings
        }
      end

      # Returns :danger elements only from the report findings
      #
      # @return [Hash]
      memoize def dangers
        @findings.select {|item| item[:status] == :danger }
      end

      private

      # Ingests RBAC from local cache directory or from running cluster 
      # depending on the command line options passed
      #
      # @return [nil]
      def ingest_rbac
        Rbac::Ingest.new(@options).run
      end

      # Constructs RBAC network view data for visualisation
      #
      # @return [nil]
      def build_rbac_network_view
        Visualisations::NetworkView::Builder.new(
          @options, 
          @ingest[:rbac_graph_network_nodes], 
          @ingest[:rbac_graph_network_edges]
        ).build
      end

      # Constructs RBAC tree view data for visualisation
      #
      # @return [nil]
      def build_rbac_tree_view
        Visualisations::TreeView::Builder.new(@options).build
      end

      # Sorts findings by their severity from danger to info
      #
      # @return [nil]
      def sort_findings
        # findings are sorted by severity status order and then by number of items found descending
        status_order = [:danger, :warning, :info, :success]
        @findings = @findings.flatten.sort_by {|f| [status_order.index(f[:status]), -f[:items].to_a.size]}.each do |i|
          @summary[i[:status]] += 1 unless i[:items].blank?
          @summary['success'] += 1 if i[:status] == :success
        end
      end

      # Executes notification/cache hooks
      #
      # @return [nil]
      def run_hooks
        slack_notifications  @findings # Slack notifications hook
        cache_dashboard_data combined  # Cache dashboard data hook
      end

      # Caches dashboard data for cosumption in the UI
      #
      # @param findings [Hash] map of risk report findings
      #
      # @return [nil]
      def cache_dashboard_data findings
        dashboard_data_dir = "#{Cli::Helpers::DATA_PATH}/#{@cluster}"
        FileUtils.mkdir_p dashboard_data_dir
        File.write("#{dashboard_data_dir}/rbac-findings.json", findings.to_json)
      end

      # Delivers Slack notifications
      #
      # @param findings [Hash] map of risk report findings
      #
      # @return [nil]
      def slack_notifications findings
        Notifications::Slack.instance.publish @cluster, findings
      end

      # Adds RBAC ingest-time findings to resultset
      #
      # @return [nil]
      def ingest_time_findings # default warnings
        info '-- Compile Ingest time findings'

        @findings << Element.build(
          id:           'missing-roles-in-bindings',
          severity:     :warning,
          group_title:  'Missing roles used in bindings',
          info:         'List of all missing roles which are referred to in RoleBindings or ClusterRoleBindings.
                        Check bindings below and create Role if required.',
          data:         @ingest[:undefined_roles],
          writer:       -> r do
                          "#{r.role_kind} #{r.role_name} referenced in #{r.binding_kind} #{r.binding_name}"
                        end
        )

        @findings << Element.build(
          id:           'dangling-roles',
          severity:     :warning,
          group_title:  'Dangling roles',
          info:         'List of all unused roles which are not bound to any Subject.
                        Roles should be reviewed and potentially removed.',
          data:         @ingest[:unused_roles],
          writer:       -> r do
                          "#{r.role_kind} #{r.role_name}"
                        end
        )

        @findings << Element.build(
          id:           'bindings-without-subjects',
          severity:     :warning,
          group_title:  'Bindings without any Subjects',
          info:         'List of all RoleBindings or ClusterRoleBindings which don\'t have any Subjects. 
                        Should those bindings exist?',
          data:         @ingest[:bindings_without_subject],
          writer:       -> r do
                          "#{r.binding_kind} #{r.binding_name}"
                        end
        )
      end

      # Adds risk rule evaluation results as a new element to findings resultset
      #
      # @return [nil]
      def finding item
        info "-- #{item.group_title}"

        @findings << Element.build(
          id:          item.id,
          severity:    item.severity,
          group_title: item.group_title,
          info:        item.info,
          data:        @graph.query(item.query),
          writer:      -> result { instance_eval(item.writer) }
        )
      end

    end
  end
end

Krane::Report::Builder.new(OpenStruct.new(cluster: ARGV[0], dir: ARGV[1])).run if __FILE__ == $0
