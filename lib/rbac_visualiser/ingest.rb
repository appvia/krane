# Understands how to retrieve and index RBAC relationships in a graph
require 'yaml'

module RbacVisualiser
  class Ingest
    include Helpers

    RBAC_CACHE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '../../' 'cache'))

    def initialize attrs
      @cluster = attrs.fetch(:cluster).to_s.downcase.strip.gsub(/\W/,'-') do
        raise "Cluster name must be specified in params!".red
      end

      @graph = RbacVisualiser::Graph.instance cluster: @cluster

      @verbose = attrs.fetch(:verbose, false)
      @index_rbac = attrs.fetch(:index, true)
      @local_rbac_dir = attrs.fetch(:dir, nil)
      @kubectl_context = attrs.fetch(:kubectlcontext, nil)

      begin
        @graph.delete if @index_rbac
      rescue => e
        banner :info, "#{e.message}. Graph `rbac-#{@cluster}` will be created." unless test?
      end

      @role_ns_lookup = {}
      @defined_roles_or_cluster_roles = Set.new
      @undefined_roles = Set.new
      @bindings_without_subject = Set.new
      @buff = []
    end

    def run
      path = "#{RBAC_CACHE_DIR}/#{@cluster}" # default path

      if @kubectl_context.present? # fetch RBAC from running cluster
        fetch_rbac @kubectl_context, path
        banner :info, "RBAC fetched from running cluster and stored in cache directory: #{path}" unless test?
      elsif @local_rbac_dir.present? # use RBAC yaml files from specified directory
        path = @local_rbac_dir
      end
      
      if @index_rbac
        index :psp, "#{path}/psp.yaml"
        index :roles, "#{path}/roles.yaml"
        index :cluster_roles, "#{path}/clusterroles.yaml"
        index :role_bindings, "#{path}/rolebindings.yaml"
        index :cluster_role_bindings, "#{path}/clusterrolebindings.yaml"

        @graph.query(%Q(CREATE #{@buff.join(',')}))
      end

      [@undefined_roles, @bindings_without_subject]
    end    

    private

    def index resource_kind, file_path
      raise "#{resource_kind.to_s.camelize} file doesn't exist: #{file_path}".red unless File.exist?(file_path)
      send("index_#{resource_kind}", file_path)
    end

    def fetch_rbac kubectl_context, path
      # fetches roles & bindings from running cluster
      info "-- Fetching RBAC from cluster"
      `mkdir -p #{path}`
      `kubectl --context=#{kubectl_context} get psp -oyaml > #{path}/psp.yaml`
      `kubectl --all-namespaces --context=#{kubectl_context} get roles -oyaml > #{path}/roles.yaml`
      `kubectl --all-namespaces --context=#{kubectl_context} get rolebinding -oyaml > #{path}/rolebindings.yaml`
      `kubectl --context=#{kubectl_context} get clusterroles -oyaml > #{path}/clusterroles.yaml`
      `kubectl --context=#{kubectl_context} get clusterrolebindings -oyaml > #{path}/clusterrolebindings.yaml`
      info "-- Fetching done"
    end

    def make_label *str
      str.flatten.join('_').downcase.gsub(/\W/,'_')
    end

    def add_node kind, label, attrs
      @buff << %Q((#{label}:#{kind} #{attrs}))
    end

    def add_relation source_label, relation, destination_label
      @buff << %Q((#{source_label})-[:#{relation}]->(#{destination_label}))
      @buff << %Q((#{source_label})<-[:#{relation}]-(#{destination_label}))
    end

    def index_psp psp
      data = YAML.load_file psp

      data['items'].each do |i|
        psp_name = i['metadata']['name']

        info "-- Indexing [#{i['kind']}] #{psp_name}"

        spec = i['spec']
        
        psp_label = make_label 'psp', psp_name

        attrs = %Q({
          name: "#{psp_name}",
          privileged: "#{spec['privileged'] || 'false'}", 
          allowPrivilegeEscalation: "#{spec['allowPrivilegeEscalation'] || 'false'}",
          allowedCapabilities: "#{spec['allowedCapabilities'].to_a.join(',')}",
          volumes: "#{spec['volumes'].to_a.join(',')}",
          hostNetwork: "#{spec['hostNetwork']}", 
          hostIPC: "#{spec['hostIPC']}",
          hostIPD: "#{spec['hostIPD']}",
          runAsUser: "#{spec['runAsUser']['rule']}",
          seLinux: "#{spec['seLinux']['rule']}",
          supplementalGroups: "#{spec['supplementalGroups']['rule']}",
          fsGroup: "#{spec['fsGroup']['rule']}"
        }).gsub(/[[:space:]]/,'')

        add_node :Psp, psp_label, attrs
      end
    end

    def index_roles(roles)
      data = YAML.load_file roles

      data['items'].each do |i|
        info "-- Indexing [#{i['kind']}] #{i['metadata']['name']}"

        role_name = i['metadata']['name']
        namespace = i['metadata']['namespace']

        role_label = make_label 'role', role_name
        ns_label = make_label namespace

        # caching role namespace scope
        @role_ns_lookup[role_label] = namespace
        
        # Node: Role
        add_node :Role, role_label, %Q({name: "#{role_name}", kind: 'Role', defined: true})
        @defined_roles_or_cluster_roles << role_name

        # Node: Namespace
        add_node :Namespace, ns_label, %Q({name: "#{namespace}"})
        # Edge: Role :SCOPE Namespace
        add_relation role_label, :SCOPE, ns_label

        # Iterating the Rules
        i['rules'].map {|rule| process_rule rule }.flatten.each do |r|
          attrs = "{" + r.map {|k,v| "#{k}: '#{v}'"}.join(", ") + "}"

          rule_label = make_label r.values

          # Node: Rule
          add_node :Rule, rule_label, attrs
          # Edge: Role :GRANT Rule
          add_relation role_label, :GRANT, rule_label
          # Edge: Rule :SECURITY Psp - for podsecuritypolicies only
          link_psp_rule rule_label, r
        end
      end
    end

    def index_cluster_roles(cluster_roles)
      data = YAML.load_file cluster_roles

      data['items'].each do |i|
        info "-- Indexing [#{i['kind']}] #{i['metadata']['name']}"

        cluster_role_name = i['metadata']['name']
        cluster_role_label = make_label 'clusterrole', cluster_role_name

        # Node: ClusterRole
        # add_node :ClusterRole, cluster_role_label, %Q({name: "#{cluster_role_name}"})
        add_node :Role, cluster_role_label, %Q({name: "#{cluster_role_name}", kind: 'ClusterRole', defined: true})
        @defined_roles_or_cluster_roles << cluster_role_name

        # Iterating ClusterRole rules
        i['rules'].map {|rule| process_rule rule }.flatten.each do |r|
          attrs = "{" + r.map {|k,v| "#{k}: '#{v}'"}.join(", ") + "}"

          rule_label = make_label r.values
           
          # Node: Rule
          add_node :Rule, rule_label, attrs
          # Edge: ClusterRole :GRANT Rule
          add_relation cluster_role_label, :GRANT, rule_label
          # Edge: Rule :SECURITY Psp - for podsecuritypolicies only
          link_psp_rule rule_label, r
        end
      end
    end

    def index_role_bindings(role_bindings)
      data = YAML.load_file role_bindings

      data['items'].each do |i|
        info "-- Indexing [#{i['kind']}] #{i['metadata']['name']}"

        role_binding_name = i['metadata']['name']
        namespace = i['metadata']['namespace']
        role_name = i['roleRef']['name']
        role_kind = i['roleRef']['kind']
        
        role_binding_label = make_label 'rolebinding', role_binding_name
        ns_label = make_label namespace

        # Role/Rolebinding created earlier - just construct label to reference that (cluster)role
        role_or_cluster_role_label = make_label role_kind, role_name

        # If role in binding hasn't been defined then it should be recorded
        register_undefined_role role_kind, role_name, :RoleBinding, role_binding_name
        
        # Node: RoleBinding
        # add_node :RoleBinding, role_binding_label, %Q({name: "#{role_binding_name}"}) 
        add_node :Binding, role_binding_label, %Q({name: "#{role_binding_name}", kind: 'RoleBinding'}) 
        # Node: Namespace
        add_node :Namespace, ns_label, %Q({name: "#{namespace}"}) 
        # Edge: RoleBinding :SCOPE Namespace      
        add_relation role_binding_label, :SCOPE, ns_label
        # Edge: RoleBinding :REFERENCE Role/RoleBinding
        add_relation role_binding_label, :REFERENCE, role_or_cluster_role_label

        if !i.has_key?('subjects') || i['subjects'].nil?
          register_binding_without_subjects :RoleBinding, role_binding_name
          next
        end

        # Iterate thorugh subjects
        i['subjects'].each do |s|
          set_subject_relations s, role_binding_label, role_or_cluster_role_label, namespace
        end

        # Create edge between related subjects used in a given binding (:subject -> [:RELATION] -> :subject)
        i['subjects'].combination(2).each do |a,b|
          set_relation_between_two_subjects a, b
        end
      end
    end

    def index_cluster_role_bindings(cluster_role_bindings)
      data = YAML.load_file cluster_role_bindings

      data['items'].each do |i|
        info "-- Indexing [#{i['kind']}] #{i['metadata']['name']}"

        cluster_role_binding_name = i['metadata']['name']
        role_name = i['roleRef']['name']
        role_kind = i['roleRef']['kind']
        
        cluster_role_binding_label = make_label 'clusterrolebinding', cluster_role_binding_name

        # Role/Rolebinding created earlier - just construct label to reference that (cluster)role
        role_or_cluster_role_label = make_label role_kind, role_name

        # If role in binding hasn't been defined then it should be recorded
        register_undefined_role role_kind, role_name, :ClusterRoleBinding, cluster_role_binding_name

        # Node: ClusterRoleBinding
        add_node :Binding, cluster_role_binding_label, %Q({name: "#{cluster_role_binding_name}", kind: 'ClusterRoleBinding'})
        # Edge: ClusterRoleBinding :REFERENCE Role/RoleBinding
        add_relation cluster_role_binding_label, :REFERENCE, role_or_cluster_role_label

        if !i.has_key?('subjects') || i['subjects'].nil?
          register_binding_without_subjects :ClusterRoleBinding, cluster_role_binding_name
          next
        end

        # Iterate thorugh subjects
        i['subjects'].each do |s|
          set_subject_relations s, cluster_role_binding_label, role_or_cluster_role_label
        end

        # create edge between related subjects used in a given binding (:subject -> [:RELATION] -> :subject)
        i['subjects'].combination(2).each do |a,b|
          set_relation_between_two_subjects a, b
        end
      end
    end

    def set_relation_between_two_subjects a, b
      a_ns = a.has_key?('namespace') ? a['namespace'] : nil
      b_ns = b.has_key?('namespace') ? b['namespace'] : nil

      # Subject created in steps above - constructing labels for reference
      a_subject_label = make_label a['name'], a['kind'], a_ns
      b_subject_label = make_label b['name'], b['kind'], b_ns

      # Edge: Subject :RELATION Subject
      add_relation a_subject_label, :RELATION, b_subject_label
    end

    def set_subject_relations s, role_or_cluster_role_binding_label, role_or_cluster_role_label, binding_namespace = nil
      subject_name = s['name']
      subject_kind = s['kind']
      # subject namespace is determined in the following priority order:
      # => subject namespace
      # => role binding namespace
      # => role namespace
      subject_namespace = if s.has_key?('namespace') && s['namespace'].present?
        s['namespace']
      elsif !binding_namespace.nil?
        binding_namespace
      else
        @role_ns_lookup.fetch(role_or_cluster_role_label, nil)
      end

      subject_label = make_label subject_name, subject_kind, subject_namespace

      # Node: Subject
      add_node :Subject, subject_label, %Q({name: "#{subject_name}", kind: "#{subject_kind}", namespace: "#{subject_namespace}"})
      # Edge: RoleBinding/ClusterRoleBinding :SUBJECT Subject
      add_relation role_or_cluster_role_binding_label, :SUBJECT, subject_label
      # Edge: Role/ClusterRole :ASSIGNED Subject
      add_relation role_or_cluster_role_label, :ASSIGN, subject_label
    end

    def link_psp_rule rule_label, rule
      # Only link access rules related to `podsecuritypolicies` resource, scoped to specific psp 
      if rule[:resource] == 'podsecuritypolicies' && !rule[:resource_name].nil?
        # prepare label for PSP based on resource_name
        psp_label = make_label 'psp', rule[:resource_name]
        # Edge: Rule :SECURITY Psp
        add_relation rule_label, :SECURITY, psp_label
      end
    end

    def process_rule rule
      if rule.has_key? 'apiGroups'
        process_resource_rule rule
      elsif rule.has_key? 'nonResourceURLs'
        process_non_resource_rule rule
      end
    end

    def process_resource_rule rule
      buff = []
      rule['apiGroups'].each do |apigroup|
        group = apigroup.empty? ? 'core' : apigroup
        rule['resources'].each do |resource|
          rule['verbs'].each do |verb|
            (rule['resourceNames'] || ['']).each do |resource_name|
              r = {type: 'resource', api_group: group, verb: verb, resource: resource}
              r.merge!(resource_name: resource_name) unless resource_name.empty?
              buff << r
            end
          end
        end
      end
      buff
    end

    def process_non_resource_rule rule
      buff = []
      rule['nonResourceURLs'].each do |url|
        rule['verbs'].each do |verb|
          buff << {type: 'non-resource', url: url, verb: verb}
        end
      end
      buff
    end

    def register_undefined_role role_kind, role_name, binding_kind, binding_name
      unless @defined_roles_or_cluster_roles.to_a.include?(role_name)
        # Add role to undefined roles dict
        @undefined_roles << { 
          role_kind: role_kind, 
          role_name: role_name, 
          binding_kind: binding_kind, 
          binding_name: binding_name 
        } 

        # Create missing Role node so it can be referred to by other entities
        # Missing Role node must have attribute {defined: false} so we can filter it in queries
        role_or_cluster_role_label = make_label role_kind, role_name
        add_node :Role, role_or_cluster_role_label, %Q({name: "#{role_name}", kind: '#{role_kind}', defined: false})
      end
    end

    def register_binding_without_subjects binding_kind, binding_name
      @bindings_without_subject << {
        binding_kind: binding_kind,
        binding_name: binding_name
      }
    end

  end
end

Rbacvis::Ingest.new(cluster: ARGV[0], dir: ARGV[1]).run if __FILE__ == $0
