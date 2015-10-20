require 'json'

require 'chef'

class Chef
class Resource
class TerraformExecute < Chef::Resource
  property :json_blob, String, required: true

  resource_name :terraform_execute

  action :plan do
    # ----- dunno how to factor this out... -----
    # may need to do some cwd footwork here, for usability.
    tmpdir = "/tmp"
    filename = name.gsub(/\s+/, '_') + ".tf.json"
    json_path = ::File.join(tmpdir, filename)

    file json_path do
      content json_blob
    end
    # --------------------------------------------

    execute "Terraform block '#{name}'" do
      command "terraform plan"
      cwd "/tmp"
    end

    log "Terraform files can be found in /tmp"
  end

  action :apply do

    # ----- dunno how to factor this out... -----
    # may need to do some cwd footwork here, for usability.
    filename = name.gsub(/\s+/, '_') + ".tf.json"

    file "/tmp/#{filename}" do
      content json_blob
    end
    # --------------------------------------------

    execute "Terraform block '#{name}'" do
      command "terraform apply"
      cwd "/tmp"
    end
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
    @attr_kv_pairs.merge!({ name => value })
  end
end

# ------------------------------------------------------------------------
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

  RESPONDABLES = TF_TOP_LEVELS + [:actions]

  def initialize(&full_tf_block)
    TF_TOP_LEVELS.each { |sym| self.send( "#{plural(sym)}=", {} ) }

    @actions = []

    instance_eval(&full_tf_block)
  end

  # ---------------------
  # Top-level directives (mostly Terraform) that require non-generic handling.
    # has to map `tf_module` onto `module`.
    def tf_module(module_name, &options_block)
      @modules[module_name] = TerraformAttributes.new(&options_block).attr_kv_pairs
    end

    # produces a different data structure than the others.
    def atlas(atlas_user)
      @atlas = { :name => atlas_user }
    end

    def action(action)
      # a resource would handle this for us, but.
      self.actions = [action].flatten
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

require 'pry'; binding.pry
  parsed.actions.each do |tf_command|
    # create a terraform_execute resource with the JSON blob.
    terraform_execute faux_resource_name do
      action tf_command
      json_blob blob
    end
  end

  # that's it.
end
