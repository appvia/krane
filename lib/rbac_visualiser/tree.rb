# Understands how to visualise RBAC

require 'json'

module RbacVisualiser
  class Tree

    def initialize attrs
      @cluster = attrs.fetch(:cluster).to_s.downcase.strip.gsub(/\W/,'-') do
        raise "Cluster name must be specified in params"
      end
      @graph = RbacVisualiser::Graph.instance cluster: @cluster
      @verbose = attrs.fetch(:verbose, false)
    end

    def build
      dir = "dashboard/data/#{@cluster}"
      FileUtils.mkdir_p dir
      File.write("#{dir}/rbac-tree.json", prepare_data)
    end

    private

    def query_graph
      res = @graph.query(%Q(
        MATCH (s:Subject)-[:ASSIGN]->(r:Role)-[:GRANT]->(ru:Rule)
        RETURN s.namespace as subject_namespace, s.kind as subject_kind, s.name as subject_name,
               r.kind as role_kind, r.name as role_name,
               ru.type as rule_type, ru.api_group as rule_api_group, ru.resource as rule_resource,
               ru.resource_name as rule_resource_name, ru.url as rule_url, ru.verb as rule_verb
        ORDER BY subject_namespace,subject_kind,subject_name,role_kind,role_name,rule_resource
      ))
      [res.columns, res.resultset]
    end

    def nested_hash
      Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    end

    def build_facet *fields
      fields.reverse.inject(nil) { |a, n| { n => a } }
    end

    def prepare_data
      namespaces = nested_hash
      subjects = nested_hash
      roles = nested_hash
      access = nested_hash
      resources = nested_hash
      
      columns, results = query_graph

      results.each do |record|
        TreeElement.build(columns, record).facets(
          namespaces: namespaces, 
          subjects: subjects, 
          roles: roles, 
          access: access, 
          resources: resources
        )
      end

      wrapper(namespaces, subjects, roles, access, resources)
    end

    def wrapper namespaces, subjects, roles, access, resources
      {
        text: "#{@cluster} cluster",
        href: "#tree",
        nodes: [
          {
            text: "Namespaces", # name
            href: "#namespaces",
            nodes: namespaces.collect {|k,v| prepare_node(k,v)} # children
          },
          {
            text: "Actors", # name
            href: "#subjects",
            nodes: subjects.collect {|k,v| prepare_node(k,v)} # children
          },
          {
            text: "Roles", # name
            href: "#roles",
            nodes: roles.collect {|k,v| prepare_node(k,v)} # children
          },
          {
            text: "Access", # name
            href: "#access",
            nodes: access.collect {|k,v| prepare_node(k,v)} # children
          },
          {
            text: "Resources", # name
            href: "#resources",
            nodes: resources.collect {|k,v| prepare_node(k,v)} # children
          }
        ]
      }.to_json
    end

    def prepare_node key, elements
        if key.is_a?(Hash)
          label = key.keys.first
          key_value = key.values.first
        else
          label = nil
          key_value = key
        end
        {
          text: key_value,
          nodes: elements.nil? ? nil : elements.collect {|ek,ev| prepare_node(ek, ev)},
        }.tap do |n|
          n[:tags] = [label] unless label.blank?
        end
    end

  end
end

Rbac::Tree.new(cluster: ARGV[0]).build if __FILE__ == $0
