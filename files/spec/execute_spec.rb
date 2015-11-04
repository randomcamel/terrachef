require 'spec_helper'
require 'cheffish/recipe_dsl'

describe "the Terrachef compiler" do
  extend Cheffish::RSpec::ChefRunSupport

  context "the terraform method" do
    it "throws exception for a missing tf configuration block"
  end

  context "TerraformCompile" do

    when_the_chef_12_server "exists", organization: 'some-org', server_scope: :context, port: 8900..9000 do
      before(:each) {
        unless ENV['AWS_ACCESS_KEY_ID'] && ENV['AWS_SECRET_ACCESS_KEY']
          fail "Terraform doesn't have a test mode, so you'll need to set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        end
      }

      it "requires an attributes block" do
        expect_converge {
          terraform "blort"
        }.to raise_error(ArgumentError, "Must pass a block to `terraform`")
      end

      it "runs a test recipe with :graph" do
        actual = ::File.open("files/spec/test_data/graph-output.dot") { |f| f.read }

        expect_recipe {

          terraform "my-terraform-block" do
            action :graph
            refresh false

            provider "docker" do
              host "tcp://192.168.59.103:2376"
              cert_path "/Users/cdoherty/.boot2docker/certs/boot2docker-vm"
            end

            provider "aws" do
              access_key  ENV['AWS_ACCESS_KEY_ID']
              secret_key  ENV['AWS_SECRET_ACCESS_KEY']
            end

            docker_container "foo" do
              image "ubuntu"
              name "running_container_name"
            end

            docker_image "ubuntu" do
              name "ubuntu:latest"
            end

            aws_security_group "fake-group" do
              name "wtf"
              description "Allow all inbound traffic"
              ingress(from_port: 0, to_port: 0, protocol: -1, cidr_blocks: ["0.0.0.0/0"])
              egress(from_port: 0, to_port: 0, protocol: -1, cidr_blocks: ["0.0.0.0/0"])
              egress(from_port: 45, to_port: true, protocol: 22, cidr_blocks: ["141.222.2.2/32", "fnord"])
            end
          end
        }.to be_truthy

        # could check the .tfstate directly from the data bag.
      end

      it "correctly fills in the default action when no action is given"
    end
  end
end
