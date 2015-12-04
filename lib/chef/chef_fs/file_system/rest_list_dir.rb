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

require 'chef/chef_fs/file_system/base_fs_dir'
require 'chef/chef_fs/file_system/rest_list_entry'
require 'chef/chef_fs/file_system/not_found_error'

class Chef
  module ChefFS
    module FileSystem
      class RestListDir < BaseFSDir
        def initialize(name, parent, api_path = nil, data_handler = nil)
          super(name, parent)
          @api_path = api_path || (parent.api_path == "" ? name : "#{parent.api_path}/#{name}")
          @data_handler = data_handler
        end

        attr_reader :api_path
        attr_reader :data_handler

        def can_have_child?(name, is_dir)
          name =~ /\.json$/ && !is_dir
        end

        #
        # Does GET /<api_path>, assumes the result is of the format:
        #
        # {
        #   "foo": "<api_path>/foo",
        #   "bar": "<api_path>/bar",
        # }
        #
        # Children are foo.json and bar.json in this case.
        #
        def children
          begin
            # Grab the names of the children, append json, and make child entries
            @children ||= root.get_json(api_path).keys.sort.map do |key|
              make_child_entry("#{key}.json", true)
            end
          rescue Timeout::Error => e
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:children, self, e, "Timeout retrieving children: #{e}")
          rescue Net::HTTPServerException => e
            # 404 = NotFoundError
            if $!.response.code == "404"
              raise Chef::ChefFS::FileSystem::NotFoundError.new(self, $!)
            # Anything else is unexpected (OperationFailedError)
            else
              raise Chef::ChefFS::FileSystem::OperationFailedError.new(:children, self, e, "HTTP error retrieving children: #{e}")
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
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, e, "Parse error reading JSON creating child '#{name}': #{e}")
          end

          # Create the child entry that will be returned
          result = make_child_entry(name, true)

          # Normalize the file_contents before post (add defaults, etc.)
          if data_handler
            object = data_handler.normalize_for_post(object, result)
            data_handler.verify_integrity(object, result) do |error|
              raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, nil, "Error creating '#{name}': #{error}")
            end
          end

          # POST /api_path with the normalized file_contents
          begin
            rest.post(api_path, object)
          rescue Timeout::Error => e
            raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, e, "Timeout creating '#{name}': #{e}")
          rescue Net::HTTPServerException => e
            # 404 = NotFoundError
            if e.response.code == "404"
              raise Chef::ChefFS::FileSystem::NotFoundError.new(self, e)
            # 409 = AlreadyExistsError
            elsif $!.response.code == "409"
              raise Chef::ChefFS::FileSystem::AlreadyExistsError.new(:create_child, self, e, "Failure creating '#{name}': #{path}/#{name} already exists")
            # Anything else is unexpected (OperationFailedError)
            else
              raise Chef::ChefFS::FileSystem::OperationFailedError.new(:create_child, self, e, "Failure creating '#{name}': #{e.message}")
            end
          end

          # Clear the cache of children so that if someone asks for children
          # again, we will get it again
          @children = nil

          result
        end

        def org
          parent.org
        end

        def environment
          parent.environment
        end

        def rest
          parent.rest
        end

        def make_child_entry(name, exists = nil)
          @children.select { |child| child.name == name }.first if @children
          RestListEntry.new(name, self, exists)
        end
      end
    end
  end
end
