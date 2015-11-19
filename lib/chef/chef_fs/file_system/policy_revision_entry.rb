require 'chef/chef_fs/file_system/rest_list_entry'
require 'chef/chef_fs/data_handler/policy_data_handler'

class Chef
  module ChefFS
    module FileSystem
      # /policies/NAME-REVISION.json
      # Represents the actual data at /organizations/ORG/policies/NAME/revisions/REVISION
      class PolicyRevisionEntry < RestListEntry
        # /policies/foo-1.0.0.json -> /policies/foo/revisions/1.0.0
        def api_path
          policy_name, revision_id = data_handler.name_and_revision(name)
          "#{parent.api_path}/#{policy_name}/revisions/#{revision_id}"
        end
      end
    end
  end
end
