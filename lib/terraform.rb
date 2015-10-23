require 'json'

require 'chef'
require 'cheffish'

class Chef
class Resource
class TerraformExecute < Chef::Resource
  property :json_blob, String, required: true
  property :refresh, [TrueClass, FalseClass], default: true  # default to false?

  property :tmpdir, String, default: "/tmp"

  resource_name :run_terraform
  default_action :graph

  def json_file_path
    filename = name.gsub(/\s+/, '_') + ".tf.json"
    json_path = ::File.join(tmpdir, filename)
  end

  action :graph do
    file json_file_path do
      content json_blob
    end

    execute "Terraform block '#{name}'" do
      command "terraform graph"
      cwd "/tmp"
    end
  end

  [:plan, :apply].each do |tf_command|
    action tf_command do
      tf_cli_command = "terraform #{tf_command} --refresh=#{refresh}"

      file json_file_path do
        content json_blob
      end

      execute "Terraform block '#{name}'" do
        command tf_cli_command
        cwd "/tmp"
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
# this is a separate class because its #method_missing behaves differently. we could do the same thing with
# some fancy footwork in TerraformCompile, but only at the cost of clarity and testability.
class TerraformAttributes

  attr_reader :attr_kv_pairs

  # given a block of stuff like this:
  # 
  # an_attribute "some value"
  # 
  # return a hash of { :an_attribute => "some value" }
  def initialize(&attributes_block)
    raise ArgumentError, "Must pass a block to TerraformAttributes" unless attributes_block
    @attr_kv_pairs = {}
    instance_eval(&attributes_block)
    if attr_kv_pairs.size == 0
      raise RuntimeError, "No attribute-value pairs found: must use the format 'my_attribute 'my_value'."
    end
  end

  def method_missing(name, value)
    new_kv = { name => value }

    # gracefully handle repeated attributes.
    if attr_kv_pairs.has_key?(name)

      # is it already an Array?
      if attr_kv_pairs[name].class == Array
        attr_kv_pairs[name] << value
      # nope, this is the first repetition.
      else
        attr_kv_pairs[name] = [attr_kv_pairs[name], value]
      end

    else
      # just treat it like a single k-v pair.
      @attr_kv_pairs.merge!(new_kv)
    end
  end

  def respond_to_missing?(method_name, include_private=false)
    true
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
    @refresh = true

    instance_eval(&full_tf_block)
  end

  # ---------------------
  # Top-level directives (mostly Terraform) that require non-generic handling.

    # this has to map `tf_module` onto `module`, which is a Ruby keyword.
    def tf_module(module_name, &options_block)
      @modules[module_name] = TerraformAttributes.new(&options_block).attr_kv_pairs
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
      data[resource_name] = TerraformAttributes.new(&attr_block).attr_kv_pairs
      return
    end

    resource_options = {}

    # eval the attributes in a different class.
    attr_kv_pairs = TerraformAttributes.new(&attr_block).attr_kv_pairs
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

  # that's it.
end
