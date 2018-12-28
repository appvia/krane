# Understands how to visualise RBAC

require 'active_support/core_ext/hash/indifferent_access'

module RbacVisualiser
  class Report
    include ::RbacVisualiser::Helpers

    def initialize attrs
      @cluster = attrs.fetch(:cluster).to_s.downcase.strip.gsub(/\W/,'-') do
        raise "Cluster name must be specified in params!".red
      end

      @verbose = attrs.fetch(:verbose, false)
      
      @undefined_roles, @bindings_without_subject = RbacVisualiser::Ingest.new(
        cluster: @cluster, 
        index: attrs.fetch(:index, true),
        dir: attrs.fetch(:dir, nil),
        kubectlcontext: attrs.fetch(:kubectlcontext, nil),
        verbose: attrs.fetch(:verbose, false)
      ).run

      RbacVisualiser::Tree.new(cluster: @cluster).build

      @graph = RbacVisualiser::Graph.instance cluster: @cluster

      @findings = []
    end

    def run
      conf_file = File.expand_path(File.join(File.dirname(__FILE__), '../../', 'config/rules.yaml'))
      config = YAML.load_file conf_file

      ingest_time_findings

      config['rules'].each do |item|
        finding item.with_indifferent_access
      end

      findings = @findings.flatten

      dashboard_data_dir = "dashboard/data/#{@cluster}"
      FileUtils.mkdir_p dashboard_data_dir
      File.write("#{dashboard_data_dir}/rbac-findings.json", findings.to_json)
      findings
    end

    private

    def ingest_time_findings #warnings
      info "-- Compile Ingest time findings"

      @findings << RbacVisualiser::ReportElement.get(
        severity: :warning,
        group_title: "Missing roles used in bindings",
        info: "List of all missing roles which are referred to in RoleBindings or ClusterRoleBindings. Check bindings below and create Role if required.",
        data: @undefined_roles,
        writer: -> r do
          "#{r[:role_kind]} #{r[:role_name]} referenced in #{r[:binding_kind]} #{r[:binding_name]}"
        end)

      @findings << RbacVisualiser::ReportElement.get(
        severity: :warning,
        group_title: "Bindings without any Subjects",
        info: "List of all RoleBindings or ClusterRoleBindings which don't have any Subjects. Should those bindings exist?",
        data: @bindings_without_subject,
        writer: -> r do
          "#{r[:binding_kind]} #{r[:binding_name]}"
        end)
    end

    def finding item
      info "-- #{item[:group_title]}"
      res = @graph.query(item[:query])

      # some report queries use threshold
      threshold = item.fetch(:threshold, 0).to_i

      @findings << RbacVisualiser::ReportElement.get(
        severity: item[:severity],
        group_title: item[:group_title],
        info: item[:info],
        data: res,
        writer: -> r { eval(item[:writer]) }
      )
    end

  end
end

if __FILE__ == $0
  say "Total time: " + Benchmark.measure do 
    RbacVisualiser::Report.new(cluster: ARGV[0], dir: ARGV[1]).run
  end.real.to_s
end

