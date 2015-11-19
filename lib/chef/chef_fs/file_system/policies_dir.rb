#
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
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
#

require 'chef/chef_fs/file_system/rest_list_dir'
require 'chef/chef_fs/file_system/policy_revision_entry'

class Chef
  module ChefFS
    module FileSystem
      #
      # Server API:
      # /policies - list of policies by name
      #   - /policies/NAME - represents a policy with all revisions
      #     - /policies/NAME/revisions - list of revisions for that policy
      #       - /policies/NAME/revisions/REVISION - actual policy-revision document
      #
      # Local Repository and ChefFS:
      # /policies - PoliciesDir - maps to server API /policies
      #   - /policies/NAME-REVISION.json - PolicyRevision - maps to /policies/NAME/revisions/REVISION
      #
      class PoliciesDir < RestListDir
        # Children: NAME-REVISION.json for all revisions of all policies
        #
        # /nodes: {
        #   "node1": "https://api.opscode.com/organizations/myorg/nodes/node1",
        #   "node2": "https://api.opscode.com/organizations/myorg/nodes/node2",
        # }
        #
        # /policies: {
        #   "foo": {}
        # }

        def make_child_entry(name, exists = nil)
          @children.select { |child| child.name == name }.first if @children
          PolicyRevisionEntry.new(name, self, exists)
        end

        # Children come from /policies in this format:
        # {
        #   "foo": {
        #     "uri": "https://api.opscode.com/organizations/essentials/policies/foo",
        #     "revisions": {
        #       "1.0.0": {
        #
        #       },
        #       "1.0.1": {
        #
        #       }
        #     }
        #   }
        # }
        def children
          begin
            # Grab the names of the children, append json, and make child entries
            @children ||= begin
              result = []
              data = root.get_json(api_path)
              data.keys.sort.each do |policy_name|
                data[policy_name]["revisions"].keys.each do |policy_revision|
                  filename = "#{policy_name}-#{policy_revision}.json"
                  result << make_child_entry(filename, true)
                end
              end
              result
            end
          rescue Timeout::Error => e
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:children, self, e), "Timeout retrieving children: #{e}"
          rescue Net::HTTPServerException => e
            # 404 = NotFoundError
            if $!.response.code == "404"
              raise Chef::ChefFS::FileSystem::NotFoundError.new(self, $!)
            # Anything else is unexpected (OperationFailedError)
            else
              raise Chef::ChefFS::FileSystem::OperationFailedError.new(:children, self, e), "HTTP error retrieving children: #{e}"
            end
          end
        end

        #
        # Does POST <api_path> with file_contents
        #
        def create_child(name, file_contents)
          # Parse the contents to ensure they are valid JSON
          begin
            object = Chef::JSONCompat.parse(file_contents)
          rescue Chef::Exceptions::JSON::ParseError => e
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, e), "Parse error reading JSON creating child '#{name}': #{e}"
          end

          # Create the child entry that will be returned
          entry = make_child_entry(name, true)

          # PolicyRevisionEntry handles creating the correct api_path etc.
          begin
            entry.write(file_contents)
          rescue Timeout::Error => e
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, e), "Timeout creating '#{name}': #{e}"
          rescue Net::HTTPServerException => e
            if e.response.code == "404"
              raise Chef::ChefFS::FileSystem::NotFoundError.new(self, e)
            elsif $!.response.code == "409"
              raise Chef::ChefFS::FileSystem::AlreadyExistsError.new(:create_child, self, e), "Failure creating '#{name}': #{path}/#{name} already exists"
            else
              raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, e), "Failure creating '#{name}': #{e.message}"
            end
          end

          # Clear the cache of children so that if someone asks for children
          # again, we will get it again
          @children = nil

          result
        end

      end
    end
  end
end
