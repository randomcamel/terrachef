require 'json'
require 'pry'

# class TerraformExecute < Chef::Resource
#   property json_blob
# end

# this is only a separate class because its #method_missing behaves differently.
class TerraformAttributes
  # use *value and value.join("")?
  def method_missing(name, value)
    @attr_kv_pairs.merge!({ name => value })
  end

  # given a block of stuff like this:
  # 
  # an_attribute "some value"
  # 
  # return a hash of { :an_attribute => "some value" }
  def compile_attribute_block(&block)
    @attr_kv_pairs = {}
    instance_eval(&block)
    @attr_kv_pairs
  end
end

class TerraformCompile
  attr_accessor :attribute_parser, :tf_data

  def initialize
    @attribute_parser = TerraformAttributes.new

    @providers = {}   # keyed by provider name.
    @resources = {}   # keyed by resource name (TF seems to do ordering via `depends_on`).
  end

  def provider(provider_name, &provider_options_block)
    options = attribute_parser.compile_attribute_block(&provider_options_block)

    @providers[provider_name] = options
  end

  def method_missing(tf_resource_type, resource_name, &attr_block)
    # puts "#{tf_resource_type} --- #{resource_name} -- block_given?==#{block_given?}"

    resource_options = {}

    # eval the attributes in a different class.
    attr_kv_pairs = attribute_parser.compile_attribute_block(&attr_block)
    resource_options.merge!(attr_kv_pairs)

    (@resources[tf_resource_type] ||= {})[resource_name] = resource_options
  end

  def compile_tf_block(&full_tf_block)
    instance_eval(&full_tf_block)
    { :providers => @providers, :resources => @resources }
  end
end

def terraform(&block)
  result = TerraformCompile.new.compile_tf_block(&block)

  puts JSON.pretty_generate(result)

  # compile the block into a JSON blob.

  # create a terraform_execute resource with the JSON blob.

  # that's it.
end