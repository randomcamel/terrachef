require "terrachef/version"

# TODO: figure out how to do this right.
$: << File.dirname(__FILE__)

require 'attribute_pairs'
require 'terraform_compile'
require 'terrachef/cheffified_tool_compiler'
require 'chef/resource/json_pseudo_resource.rb'
require 'chef/resource/terraform_execute'
