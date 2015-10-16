require 'json'
require 'pry'

# class TerraformExecute < Chef::Resource
#   property json_blob
# end

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
    @tf_resources = []
    @header = "header not set"
  end

  def provider(provider_name, &provider_options_block)
    options = attribute_parser.compile_attribute_block(&provider_options_block)

    @header = { :provider => { provider_name => options } }
  end

  def method_missing(tf_resource_type, resource_name, &attr_block)
    # puts "#{tf_resource_type} --- #{resource_name} -- block_given?==#{block_given?}"

    resource_data = { :resource => { tf_resource_type => { resource_name => {} }}}

    # only the Terraform resource itself will pass a block. otherwise it's our faux "attributes".
    if attr_block
      attr_kv_pairs = attribute_parser.compile_attribute_block(&attr_block)

      resource_data[:resource][tf_resource_type][resource_name].merge!(attr_kv_pairs)
    end

    @tf_resources << resource_data.merge(@header)
  end

  def compile_tf_block(&full_tf_block)
    instance_eval(&full_tf_block)
  end
end

def terraform(&block)
  result = TerraformCompile.new.compile_tf_block(&block)

  puts JSON.pretty_generate(result)

  # compile the block into a JSON blob.

  # create a terraform_execute resource with the JSON blob.

  # that's it.
end