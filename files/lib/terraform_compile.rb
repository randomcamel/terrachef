require 'terrachef/cheffified_tool_compiler'

# ------------------------------------------------------------------------
# From a high level, it looks like this could be a real Chef::Resource, since we're faking properties and
# actions, and creating inner resources. That's true only if we can safely have our own #method_missing.
class TerraformCompile < Terrachef::CheffifiedToolCompiler

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

  def self.respondables
    TF_TOP_LEVELS
  end

  def respondables; self.class.respondables; end

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
    self.respondables.include?(method_name) || super
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
