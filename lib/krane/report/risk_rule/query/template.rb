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

# Understands how to build graph queries from template for given query kind

module Krane
  module Report
    module RiskRule
      module Query
        module Template
          extend self

          DEFAULT_TEMPLATE = :risky_role

          class UnknownTemplate < StandardError; end

          # Gets query / writer template based on kind
          #
          # @param kind [Symbol/String] template kind name
          # @param matches [String] (Optional) graph query matches expression
          # @param where [String] (Optional) graph query where condition
          #
          # @return [OpenStruct] responding to :query & :writer
          def for kind:, matches: nil, where: nil
            @matches = matches
            @where   = where

            m = kind.to_s.underscore.downcase.to_sym
            respond_to?(m) ? send(m) : unknown_template(m)
          end

          def unknown_template tpl
            raise UnknownTemplate.new(
              "Undefined template `#{tpl}` referenced in the risk rules configuration")
          end

          #
          # ==== Built-in Commands ====
          #


          #
          # ==== Risk Report ====
          #

          # Query/writer template for `risky-role`. Default.
          def risky_role
            where_condition = [
              @where, "NOT ro0.name IN {{whitelist_role_names}}"
            ].compact.reject {|c| c.empty? }.join(' AND ')

            OpenStruct.new(
              query: %Q(
                #{@matches}
                WHERE
                #{where_condition}
                RETURN 
                  ro0.name as role_name,
                  ro0.kind as role_kind,
                  COLLECT(ns.name) as namespace_name
                ORDER BY 
                  role_kind,
                  role_name,
                  namespace_name
              ),
              writer: <<-'EOF'
                "#{result.role_kind} #{result.role_name} in #{result.namespace_name.include?('*') ? '*' : result.namespace_name.join(', ')} namespace(s)"
              EOF
            )
          end

          # Query/writer template for `privileged-psp-subjects`.
          def privileged_psp_subjects
            OpenStruct.new(
              query: %Q(
                MATCH 
                  (p:Psp {privileged: 'true'})-[:SECURITY]->(r:Rule)
                  <-[:GRANT]-(ro:Role {is_default: 'false'})
                  <-[:ASSIGN]-(s:Subject)-[:ACCESS]->(ns:Namespace {name: '*'})
                WHERE 
                  ro.defined = 'true'
                  AND NOT s.name IN {{whitelist_subject_names}}
                RETURN 
                  p.name as psp_name, 
                  s.kind as subject_kind,
                  s.name as subject_name
              ),
              writer: <<-'EOF'
                "#{result.subject_kind} #{result.subject_name} able to run privileged psp #{result.psp_name}"
              EOF
            )
          end

          # Query/writer template for `unrestricted-cluster-wide-subjects`
          def unrestricted_cluster_wide_subjects
            OpenStruct.new(
              query: %Q(
                MATCH 
                  (r:Rule)<-[:GRANT]-(ro:Role {is_default: 'false'})
                  <-[:ASSIGN]-(s:Subject)-[:ACCESS]->(ns:Namespace {name: '*'})
                WHERE 
                  ((r.api_group = '*' OR r.api_group = 'core') AND (r.resource = '*' OR r.url = '*') AND r.verb = '*')
                  AND ro.defined = 'true'
                  AND NOT s.name IN {{whitelist_subject_names}}
                RETURN 
                  r.api_group as rule_api_group,
                  r.type as rule_type,
                  s.kind as subject_kind, 
                  s.name as subject_name
                ORDER BY 
                  subject_name,
                  subject_kind            
              ),
              writer: <<-'EOF'
                txt = result.rule_type == 'resource' ? 'resources' : 'non-resource URLs'
                "#{result.subject_kind} #{result.subject_name} has * access to * #{txt} (apiGroup: #{result.rule_api_group})"
              EOF
            )
          end

          # Query/writer template for `unrestricted-ns-level-subjects`
          def unrestricted_ns_level_subjects
            OpenStruct.new(
              query: %Q(
                MATCH 
                  (r:Rule)<-[:GRANT]-(ro:Role {is_default: 'false'})
                  <-[:ASSIGN]-(s:Subject)-[:ACCESS]->(ns:Namespace)
                WHERE 
                  ((r.api_group = '*' OR r.api_group = 'core') AND (r.resource = '*' OR r.url = '*') AND r.verb = '*')
                  AND ns.name <> '*'
                  AND ro.defined = 'true'
                  AND NOT s.name IN {{whitelist_subject_names}}
                RETURN 
                  r.api_group as rule_api_group,
                  r.type as rule_type,
                  s.kind as subject_kind,
                  s.name as subject_name,
                  ns.name as namespace_name
                ORDER BY
                  namespace_name,
                  subject_name,
                  subject_kind
              ),
              writer: <<-'EOF'
                txt = result.rule_type == 'resource' ? 'resources' : 'non-resource URLs'
                "#{result.subject_kind} #{result.subject_name} has * access to * #{txt} (apiGroup: #{result.rule_api_group}) in #{result.namespace_name} namespace"
              EOF
            )
          end

          # Query/writer template for `rbac-managing-subjects`
          def rbac_managing_subjects
            OpenStruct.new(
              query: %Q(
                MATCH 
                  (r:Rule)<-[:GRANT]-(ro:Role {is_default: 'false', defined: 'true'})
                  <-[:ASSIGN]-(s:Subject)-[:ACCESS]->(ns:Namespace)
                WHERE 
                  (r.verb = 'create' OR r.verb = '*')
                  AND (r.api_group = 'rbac.authorization.k8s.io' OR r.api_group = '*') 
                  AND (r.resource = 'roles' OR r.resource = 'rolebindings' OR r.resource = '*')
                  AND NOT s.name IN {{whitelist_subject_names}}
                RETURN 
                  s.kind as subject_kind, 
                  s.name as subject_name, 
                  ns.name as namespace_name
                ORDER BY 
                  subject_kind, 
                  subject_name DESC
              ),
              writer: <<-'EOF'
                "#{result.subject_kind} #{result.subject_name} (in #{result.namespace_name} namespace)"
              EOF
            )
          end

          # Query/writer template for `undefined-role-subjects`
          def undefined_role_subjects
            OpenStruct.new(
              query: %Q(
                MATCH 
                  (s:Subject)-[:ASSIGN]->(r:Role {defined: 'false'})
                RETURN 
                  r.kind as role_kind,
                  r.name as role_name, 
                  s.kind as subject_kind, 
                  s.name as subject_name
                ORDER BY 
                  subject_kind,
                  subject_name 
              ),
              writer: <<-'EOF'
                "#{result.subject_kind} #{result.subject_name} is bound to non-existing #{result.role_kind} #{result.role_name}"
              EOF
            )
          end

          # Query/writer template for `multiple-role-subjects`
          def multiple_role_subjects
            OpenStruct.new(
              query: %Q(
                MATCH 
                  (s:Subject)-[:ASSIGN]->(r:Role {is_default: 'false', defined: 'true'})
                WHERE 
                  NOT s.name IN {{whitelist_subject_names}}
                RETURN 
                  COUNT(r) as role_count,
                  s.kind as subject_kind, 
                  s.name as subject_name
                ORDER BY 
                  role_count, 
                  subject_kind,
                  subject_name DESC
              ),
              writer: <<-'EOF'
                "#{result.subject_kind} #{result.subject_name} referenced by #{result.role_count.to_i} roles" if result.role_count.to_i >= {{threshold}}
              EOF
            )
          end

          # Query/writer template for `multiple-subject-namespaces`
          def multiple_subject_namespaces
            OpenStruct.new(
              query: %Q(
                MATCH 
                  (ns:Namespace)-[:ACCESS]->(s:Subject)
                WHERE 
                  NOT ns.name IN {{whitelist_namespace_names}}
                RETURN 
                  COUNT(s.name) as subject_count,
                  ns.name as namespace_name
                ORDER BY 
                  subject_count,
                  namespace_name DESC
              ),
              writer: <<-'EOF'
                "#{result.namespace_name} allows #{result.subject_count.to_i} subject(s)" if result.subject_count.to_i >= {{threshold}}
              EOF
            )
          end

        end
      end
    end
  end
end
