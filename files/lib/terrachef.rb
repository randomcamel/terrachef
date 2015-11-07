require "terrachef/version"

# TODO: figure out how to do this right.
$: << File.dirname(__FILE__)
require 'terraform'
require 'attribute_pairs'
require 'terraform_compile'
require 'chef/resource/terraform_execute'
