require 'json'

# class TerraformExecute < Chef::Resource
#   property json_blob
# end

class TerraformAttributes
  def method_missing(name, value)
    { name => value }
  end

  def compile_attribute_block(&block)
    instance_eval(&block)
  end
end

class TerraformCompile
  attr_accessor :attribute_parser

  def initialize
    @attribute_parser = TerraformAttributes.new
  end

  def provider(provider_name, &block)
    raise "Not ready yet"
  end

  def method_missing(tf_resource, resource_name, &attr_block)
    puts "#{tf_resource} --- #{resource_name} -- block_given?==#{block_given?}"

    tf_data =  { resource: tf_resource, name: resource_name }

    # only the Terraform resource itself will pass a block.
    if attr_block
      tf_data.merge(attribute_parser.compile_attribute_block(&attr_block))
    end
  end

  def compile_tf_block(&block)
    instance_eval(&block)
  end
end

def terraform(&block)
  result = TerraformCompile.new.compile_tf_block(&block)

  puts JSON.pretty_generate(result)

  # compile the block into a JSON blob.

  # create a terraform_execute resource with the JSON blob.

  # that's it.
end