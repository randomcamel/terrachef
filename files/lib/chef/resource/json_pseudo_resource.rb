require 'json'

require 'cheffish'

class Chef
class Resource
class JSONPseudoResource < Chef::Resource

  resource_name :json_pseudo_resource

  allowed_actions [:nothing]

  property :json_blob, String, required: true

  property :tmpdir, String, default: "/tmp"
  property :canonical_name, String, default: lazy { name.gsub(/\s+/, '_') }
  property :json_filename, String, default: lazy { raise "override json_filename in subclass" }
  property :full_json_path, String, default: lazy { ::File.join(tmpdir, tf_filename) }

  property :data_bag_name, String, default: lazy { canonical_name }

  # add a CCR handler to delete the temporary tfstate directory.

  # magic invocation to be able to use resources inside helper functions.
  declare_action_class.class_eval do
    def write_json_file
      file json_path do
        content json_blob
      end
    end

    def slurp(path)
      raise ArgumentError, "Empty path in slurp()." if path.to_s.empty?
      ::File.open(path) { |f| f.read }
    end

    def ensure_data_bag
      chef_data_bag data_bag_name
    end

    def save_data(key, data, data_bag=canonical_name)
      ruby_block "save tf data in data bag #{data_bag}" do
        block do
          data = {
            "id" => canonical_name,
            "tf_json" => JSON.parse(slurp(json_path)),
          }

          # we may not have a .tfstate file yet, which is fine.
          begin
            data["tf_state"] = JSON.parse(slurp(::File.join(tmpdir, TFSTATE_FILENAME)))
          rescue
          end

          item = Chef::DataBagItem.new
          item.data_bag(data_bag_name)
          item.raw_data = data
          item.save
        end
      end
    end

    def load_data(key, data, data_bag=canonical_name)
      ruby_block "load tf data from data bag #{canonical_name}" do
        block do
          begin
            data = data_bag_item(data_bag_name, canonical_name)

            # this is the only file we write out; everything else is just for reference.
            if data.has_key?("tf_state")
              ::File.open(tfstate_file, 'w') { |f| f.puts data["tf_state"]}
            end
          rescue Net::HTTPServerException
            # could be the first run, could be something else. either way, nonexistent bag is OK.
          end
        end
      end
    end
  end
end
end
end
