require 'json'

require 'spec_helper'

describe TerraformCompile do

  def parse_file(test_filename)
    JSON.parse(File.open("spec/test_data/#{test_filename}").read)
  end

  let(:basic_tf_data) { parse_file("basic.tf.json") }
  let(:my_tf_data)    { parse_file("recipe_output.tf.json") }

  context "converting pseudo-Chef to Terraform data" do
    context "attributes" do
      it "converts an attributes block to a hash" do
        expected = { "foo" => 23, "blargh" => "a string" }
        actual = TerraformAttributes.new do
          foo 42
          blargh "a string"
          foo 23
        end.attr_kv_pairs

        expect(actual).to eq(expected)
      end
    end

    context "full TF blocks" do
      it "parses my own TF recipe into TF data" do
        actual = TerraformCompile.new do
          provider "docker" do
            host "tcp://192.168.59.103:2376"
            cert_path "/Users/cdoherty/.boot2docker/certs/boot2docker-vm"
          end

          provider "aws" do
            aws_secret "some-secret"
            aws_key    "some-key"
          end

          docker_container "foo" do
            image "ubuntu:latest"
            name "running_container_name"
          end

          docker_image "ubuntu" do
            name "ubuntu:latest"
          end
        end.to_tf_data

        expect(actual).to eq(my_tf_data)
      end

      it "parses a TF recipe into TF's sample data"
    end
  end
end