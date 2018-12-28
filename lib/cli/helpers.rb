module Cli
  module Helpers

    def raise_on_cluster_missing options
      raise 'Cluster not defined. Use --cluster [CLUSTER_NAME] to define it.' if options.cluster.blank?
    end

    def raise_on_cluster_report_missing options
      return if dashboard_data_exists? options.cluster
      raise "There is no data to show for #{options.cluster} cluster. Run the report first: `rbacvis report -c #{options.cluster}`"
    end

    def raise_on_missing_path_or_context options
      unless [options.dir, options.kubectlcontext].any?
        raise "Must provide one of flags: --dir [PATH], --kubectlcontext [CONTEXT]."
      end
    end

    def dashboard_data_exists? cluster
      f = -> (file) do 
        File.exist?(File.join(File.expand_path(File.dirname(__FILE__)), '../../', file))
      end

      [
        f.call("dashboard/data/#{cluster}/rbac-tree.json"),
        f.call("dashboard/data/#{cluster}/rbac-findings.json"),
      ].all?
    end

  end
end
