require 'json'

require 'chef'

class Chef
class Resource
class TerraformExecute < Chef::Resource
  property :json_blob, String, required: true
  # property state_file   # seems likely?

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

# this is only a separate class because its #method_missing behaves differently.
class TerraformAttributes

  attr_reader :attr_kv_pairs

  # given a block of stuff like this:
  # 
  # an_attribute "some value"
  # 
  # return a hash of { :an_attribute => "some value" }
  def initialize(&attributes_block)
    raise ArgumentError("Must pass a block to TerraformAttributes") unless attributes_block
    @attr_kv_pairs = {}
    instance_eval(&attributes_block)
  end

  def method_missing(name, value)
    @attr_kv_pairs.merge!({ name => value })
  end
end

class TerraformCompile
  # these are to avoid #instance_variable_get, which just looks gross. note that these rely on the naming
  # convention of being "#{terraform_section_name}s".
  attr_reader :providers, :resources, :outputs, :variables, :provisioners

  def initialize(&full_tf_block)
    @providers = {}   # keyed by provider name.
    @resources = {}   # keyed by resource name (TF seems to do ordering via `depends_on`).
    @variables = {}
    @outputs   = {}
    @provisioners = {}
    @actions   = []

    instance_eval(&full_tf_block)
  end

  def action(action_list=nil)
    if action_list
      @actions = [action_list].flatten
    else
      @actions
    end
  end

  def atlas(atlas_user)
    @atlas = { :name => atlas_user }
  end

  def provider(provider_name, &options_block)
    @providers[provider_name] = TerraformAttributes.new(&options_block).attr_kv_pairs
  end

  def variable(variable_name, &options_block)
    @variables[variable_name] = TerraformAttributes.new(&options_block).attr_kv_pairs
  end

  def output(output_name, &options_block)
    @outputs[output_name] = TerraformAttributes.new(&options_block).attr_kv_pairs
  end

  def provisioner(provisioner_name, &options_block)
    @provisioners[provisioner_name] = TerraformAttributes.new(&options_block).attr_kv_pairs
  end

  def method_missing(tf_resource_type, resource_name, &attr_block)

    raise ArgumentError("Terraform resources require a block with options.") unless attr_block

    resource_options = {}

    # eval the attributes in a different class.
    attr_kv_pairs = TerraformAttributes.new(&attr_block).attr_kv_pairs
    resource_options.merge!(attr_kv_pairs)

    (@resources[tf_resource_type.to_s] ||= {})[resource_name] = resource_options
  end


  def to_tf_data
    result = {}

    # tf uses the singular, we use the plural. luckily: Ruby!
    %w(provider resource variable output provisioner).each do |tf_type|
      data = self.send("#{tf_type}s".to_sym)

      result.merge!(tf_type => data) if data.size > 0
    end

    result.merge!(atlas: @atlas) if @atlas
    result
  end

  def to_tf_json
    JSON.pretty_generate(self.to_tf_data)
  end
end

# it seems likely there's a cleaner way to do this than having a global method.
def terraform(faux_resource_name, &full_tf_block)

  # compile the block into a JSON blob.
  parsed = TerraformCompile.new(&full_tf_block)

  puts parsed.action.inspect
  blob = parsed.to_tf_json

  parsed.action.each do |tf_action|
    # create a terraform_execute resource with the JSON blob.
    terraform_execute faux_resource_name do
      action tf_action
      json_blob blob
    end
  end

  # that's it.
end