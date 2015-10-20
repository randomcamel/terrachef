require 'spec_helper'

describe "the Terrachef compiler" do
  extend Cheffish::RSpec::ChefRunSupport

  context "the terraform method" do
    it "throws exception for a missing tf configuration block"
  end

  context "TerraformCompile" do
    it "requires an attributes block" do
      expect_converge {
        terraform "blort"
      }.to raise_error(ArgumentError, "Must pass a block to `terraform`")
    end

    it "runs a test recipe" do
      skip "broken"
      ENV['TERRACHEF_NOOP'] = "yes"

      expect_converge {
        terraform "my-terraform-block" do
          provider "docker" do
            host "tcp://192.168.59.103:2376"
            cert_path "/Users/cdoherty/.boot2docker/certs/boot2docker-vm"
          end

          provider "aws" do
            aws_secret "some-secret"
            aws_key    "some-key"
          end

          docker_container "foo" do
            image "ubuntu"
            name "running_container_name"
          end

          docker_image "ubuntu" do
            name "ubuntu:latest"
          end
        end
      }
    end
  end
end