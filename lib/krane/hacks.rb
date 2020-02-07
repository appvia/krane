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

# Various monkey patching

# redisgraph-rb fix for dealing with COLLECT
class QueryResult
  def map_scalar(type, val)
    # puts "----> type: #{type}, val: #{val}"
    map_func = case type
              when 1 # null
                return nil
              when 2 # string
                :to_s
              when 3 # integer
                :to_i
              when 4 # boolean
                # no :to_b
                return val == "true"
              when 5 # double
                :to_f
              # TODO: when in the distro packages and docker images,
              #   the following _should_ work
              # when 6 # array
              #   val.map { |it| map_scalar(it[0], it[1]) }
              end

    val.is_a?(Array) ? val.map {|i| map_scalar(i[0], i[1])} : val.send(map_func)
  end
end
