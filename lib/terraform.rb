require 'json'
require 'pry'

require 'chef'

class TerraformExecute < Chef::Resource
  property :json_blob, String, required: true
  # property state_file   # seems likely?

  resource_name :terraform_execute

  # hack: these different actions should be exposed usefully to the user.
  tf_args = ENV['TERRACHEF_NOOP'] ? "plan" : "apply"

  action :apply do

    # may need to do some cwd footwork here, for usability.
    filename = name.gsub(/\s+/, '_') + ".tf.json"

    file "/tmp/#{filename}" do
      content json_blob
    end

    execute "Terraform block '#{name}'" do
      command "terraform #{tf_args}"
      cwd "/tmp"
    end
  end

  action :plan do
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
    # raise ArgumentError("Must pass a block to TerraformAttributes") unless attributes_block
    @attr_kv_pairs = {}
    instance_eval(&attributes_block)
  end

  # use *value and value.join("")?
  def method_missing(name, value)
    @attr_kv_pairs.merge!({ name.to_s => value })
  end
end

class TerraformCompile
  attr_accessor :tf_data, :providers, :resources, :outputs, :variables

  def initialize(&full_tf_block)
    @providers = {}   # keyed by provider name.
    @resources = {}   # keyed by resource name (TF seems to do ordering via `depends_on`).
    @variables = {}
    @outputs   = {}

    instance_eval(&full_tf_block)
  end

  def atlas(atlas_user)
    @atlas = { :name => atlas_user }
  end

  def provider(provider_name, &options_block)
    options = TerraformAttributes.new(&options_block).attr_kv_pairs
    @providers[provider_name] = options
  end

  def variable(variable_name, &options_block)
    @variables[variable_name] = TerraformAttributes.new(&options_block).attr_kv_pairs
  end

  def output(output_name, &options_block)
    @outputs[output_name] = TerraformAttributes.new(&options_block).attr_kv_pairs
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
    %w(provider resource variable output).each do |tf_type|
      data = self.send("#{tf_type}s".to_sym)
      if data.size > 0
        result.merge!(tf_type => data)
      end
    end

    result.merge!(atlas: @atlas) if @atlas
    result
  end

  def to_tf_json
    JSON.pretty_generate(self.to_tf_data)
  end
end

def terraform(faux_resource_name, &full_tf_block)

  # compile the block into a JSON blob.
  parsed = TerraformCompile.new(&full_tf_block)
  blob = parsed.to_tf_json
  # puts blob

  # create a terraform_execute resource with the JSON blob.
  terraform_execute faux_resource_name do
    json_blob blob
  end

  # that's it.
end