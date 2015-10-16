require 'json'
require 'pry'

# class TerraformExecute < Chef::Resource
#   property json_blob
# end

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
  attr_accessor :attribute_parser, :tf_data

  def initialize(&full_tf_block)
    @providers = {}   # keyed by provider name.
    @resources = {}   # keyed by resource name (TF seems to do ordering via `depends_on`).

    instance_eval(&full_tf_block)
  end

  def provider(provider_name, &provider_options_block)
    options = TerraformAttributes.new(&provider_options_block).attr_kv_pairs

    @providers[provider_name] = options
  end

  def method_missing(tf_resource_type, resource_name, &attr_block)
    # puts "#{tf_resource_type} --- #{resource_name} -- block_given?==#{block_given?}"

    resource_options = {}

    # eval the attributes in a different class.
    attr_kv_pairs = TerraformAttributes.new(&attr_block).attr_kv_pairs
    resource_options.merge!(attr_kv_pairs)

    (@resources[tf_resource_type.to_s] ||= {})[resource_name] = resource_options
  end


  def to_tf_data
    { "providers" => @providers, "resources" => @resources }
  end

  def to_tf_json
    JSON.pretty_generate(self.to_tf_data)
  end
end

def terraform(&full_tf_block)

  # compile the block into a JSON blob.
  parsed = TerraformCompile.new(&full_tf_block)
  puts parsed.to_tf_json

  # create a terraform_execute resource with the JSON blob.

  # that's it.
end