require 'json'

require 'chef'
require 'cheffish'

class Chef
class Resource
class TerraformExecute < Chef::Resource

  resource_name :run_terraform
  default_action :graph

  property :json_blob, String, required: true
  property :refresh, [TrueClass, FalseClass], default: false

  property :tmpdir, String, default: "/tmp"
  property :canonical_name, String, default: lazy { name.gsub(/\s+/, '_') }
  property :tf_filename, String, default: lazy { "#{canonical_name}.tf.json" }
  property :json_path, String, default: lazy { ::File.join(tmpdir, tf_filename) }
  property :data_bag_name, String, default: lazy { canonical_name }
  property :tfstate_file, String, default: lazy { ::File.join(tmpdir, TFSTATE_FILENAME) }

  TFSTATE_FILENAME = "terraform.tfstate"

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

    def save_tfdata
      ruby_block "save tf data in data bag #{canonical_name}" do
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

    def load_tfdata
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

  action :graph do

    write_json_file

    execute "Terraform block '#{name}'" do
      command "terraform graph"
      cwd tmpdir
    end
  end

  [:plan, :apply].each do |tf_command|
    action tf_command do

      os_tmpdir = Dir.mktmpdir
      begin
        tmpdir os_tmpdir

        tf_cli_command = "terraform #{tf_command} --refresh=#{refresh}"

        ensure_data_bag
        write_json_file

        load_tfdata

        execute "Terraform block '#{name}'" do
          command tf_cli_command
          cwd tmpdir
        end

        save_tfdata
      end
      log "Terraform files can be found in #{tmpdir}"
    end
  end

  action :noop do
    log "noop noop noop noop"
  end
end
end
end



# ------------------------------------------------------------------------

# From a high level, it looks like this could be a real Chef::Resource, since we're faking properties and
# actions, and creating inner resources. That's true only if we can safely have our own #method_missing.
class TerraformCompile

  TF_TOP_LEVELS = [:provider, :resource, :variable, :output, :provisioner, :module]

  def self.plural(singular)
    "#{singular}s".to_sym
  end
  def plural(singular)
    self.class.plural(singular)
  end

  # these are to avoid #instance_variable_get, which just looks gross.
  TF_TOP_LEVELS.each { |sym| attr_accessor self.plural(sym) }

  attr_accessor :actions

  RESPONDABLES = TF_TOP_LEVELS

  def initialize(&full_tf_block)
    TF_TOP_LEVELS.each { |sym| self.send( "#{plural(sym)}=", {} ) }

    @actions = Chef::Resource::TerraformExecute.default_action
    @refresh = Chef::Resource::TerraformExecute.properties[:refresh].default

    instance_eval(&full_tf_block)
  end

  # ---------------------
  # Top-level directives (mostly Terraform) that require non-generic handling.

    # this has to map `tf_module` onto `module`, which is a Ruby keyword.
    def tf_module(module_name, &options_block)
      @modules[module_name] = AttributePairs.new(&options_block).attr_kv_pairs
    end

    # produces a different data structure than the others.
    def atlas(atlas_user)
      @atlas = { :name => atlas_user }
    end

    # these are required for being a faux-resource.
    def action(action)
      self.actions = [action].flatten
    end

    def refresh(do_refresh=nil)
      @refresh = do_refresh if !do_refresh.nil?
      @refresh
    end
  # ---------------------

  # https://robots.thoughtbot.com/always-define-respond-to-missing-when-overriding
  def respond_to_missing?(method_name, include_private=false)
    RESPONDABLES.include?(method_name) || super
  end

  def method_missing(tf_resource_type, resource_name, &attr_block)

    raise ArgumentError("Terraform resources require a block with options.") unless attr_block

    if TF_TOP_LEVELS.include?(tf_resource_type)
      Chef::Log.info("Parsing Terraform resource #{tf_resource_type}")

      data = self.send( plural(tf_resource_type) )
      data[resource_name] = AttributePairs.new(&attr_block).attr_kv_pairs
      return
    end

    resource_options = {}

    # eval the attributes in a different class.
    attr_kv_pairs = AttributePairs.new(&attr_block).attr_kv_pairs
    resource_options.merge!(attr_kv_pairs)

    (@resources[tf_resource_type.to_s] ||= {})[resource_name] = resource_options
  end

  def to_tf_data
    result = {}

    # tf uses the singular, we use the plural. luckily: Ruby!
    TF_TOP_LEVELS.each do |tf_type|
      data = self.send( plural(tf_type).to_sym )

      result.merge!(tf_type => data) if data.size > 0
    end

    # we can eventually treat @atlas like we do everything else.
    result.merge!(atlas: @atlas) if @atlas
    result
  end

  def to_tf_json
    JSON.pretty_generate(self.to_tf_data)
  end
end

# there's probably a cleaner way to do this than having a global method--maybe using the world's weirdest Chef
# resource or something, or tacking it onto the client run.
def terraform(faux_resource_name, &full_tf_block)

  raise ArgumentError, "Must pass a block to `terraform`" unless full_tf_block

  # compile the block into a JSON blob.
  parsed = TerraformCompile.new(&full_tf_block)

  blob = parsed.to_tf_json

  # create a run_terraform resource with the JSON blob.
  run_terraform faux_resource_name do
    action parsed.actions
    refresh parsed.refresh
    json_blob blob
  end

  # that's it. the Chef CCR will do the rest.
end
