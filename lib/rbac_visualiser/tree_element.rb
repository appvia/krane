require 'hashie'

module RbacVisualiser
  class TreeElement < Hashie::Mash
    
    ALL_NAMESPACES = "[ALL NAMESPACES]"

    def self.build columns, record
      new(columns.zip(record).to_h)
    end

    def facets facets
      facets.each do |name, facet|
        method_name = name.to_sym
        send(method_name, facet) if self.respond_to?(method_name)
      end
      
    end

    def namespaces facet
      if rule_type == 'resource' && resource_name
        facet[namespace: namespace][subject_kind][subject_kind => subject_name][rule_type]['API': rule_api_group][resource: rule_resource]['resource name': resource_name][verb: rule_verb][role_kind => role_name] = nil
      elsif rule_type == 'resource'
        facet[namespace: namespace][subject_kind][subject_kind => subject_name][rule_type]['API': rule_api_group][resource: rule_resource][verb: rule_verb][role_kind => role_name] = nil
      else
        facet[namespace: namespace][subject_kind][subject_kind => subject_name][rule_type]['URL': rule_url][verb: rule_verb][role_kind => role_name] = nil
      end
    end

    def subjects facet
      if rule_type == 'resource' && resource_name
        facet[actor: subject_kind][subject_kind => subject_name][namespace: namespace][rule_type]['API': rule_api_group][resource: rule_resource]['resource name': resource_name][verb: rule_verb][role_kind => role_name] = nil
      elsif rule_type == 'resource'
        facet[actor: subject_kind][subject_kind => subject_name][namespace: namespace][rule_type]['API': rule_api_group][resource: rule_resource][verb: rule_verb][role_kind => role_name] = nil
      else
        facet[actor: subject_kind][subject_kind => subject_name][namespace: namespace][rule_type]['URL': rule_url][verb: rule_verb][role_kind => role_name] = nil
      end
    end

    def roles facet
      if rule_type == 'resource' && resource_name
        facet[role_kind][role_kind => role_name][rule_type]['API': rule_api_group][resource: rule_resource]['resource name': resource_name][verb: rule_verb][namespace: namespace][subject_kind][subject_kind => subject_name] = nil
      elsif rule_type == 'resource'
        facet[role_kind][role_kind => role_name][rule_type]['API': rule_api_group][resource: rule_resource][verb: rule_verb][namespace: namespace][subject_kind][subject_kind => subject_name] = nil
      else
        facet[role_kind][role_kind => role_name][rule_type]['URL': rule_url][verb: rule_verb][namespace: namespace][subject_kind][subject_kind => subject_name] = nil
      end
    end

    def access facet
      if rule_type == 'resource' && resource_name
        facet[rule_type]['API': rule_api_group][resource: rule_resource]['resource name': resource_name][verb: rule_verb][role_kind][role_kind => role_name][actor: subject_kind][subject_kind => subject_name][namespace: namespace] = nil
      elsif rule_type == 'resource'
        facet[rule_type]['API': rule_api_group][resource: rule_resource][verb: rule_verb][role_kind][role_kind => role_name][actor: subject_kind][subject_kind => subject_name][namespace: namespace] = nil
      else
        facet[rule_type]['URL': rule_url][verb: rule_verb][role_kind][role_kind => role_name][actor: subject_kind][subject_kind => subject_name][namespace: namespace] = nil
      end
    end

    def resources facet
      if rule_type == 'resource' && resource_name
        facet[rule_type]['API': rule_api_group][resource: rule_resource]['resource name': resource_name][verb: rule_verb][role_kind][role_kind => role_name][subject_kind][subject_kind => subject_name][namespace: namespace] = nil
      elsif rule_type == 'resource'
        facet[rule_type]['API': rule_api_group][resource: rule_resource][verb: rule_verb][role_kind][role_kind => role_name][subject_kind][subject_kind => subject_name][namespace: namespace] = nil
      else
        facet[rule_type]['URL': rule_url][verb: rule_verb][role_kind][role_kind => role_name][subject_kind][subject_kind => subject_name][namespace: namespace] = nil
      end
    end

    private  # Helpers

    def namespace
      return ALL_NAMESPACES if subject_namespace.empty?
      subject_namespace
    end

    def resource_name
      return nil if rule_resource_name == 'NULL'
      rule_resource_name
    end

  end
end
