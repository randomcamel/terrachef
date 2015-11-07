require 'json'

require 'spec_helper'

describe TerraformCompile do

  def parse_file(test_filename)
    JSON.parse(File.open("files/spec/test_data/#{test_filename}").read)
  end

  let(:basic_tf_data) { parse_file("basic.tf.json") }
  let(:my_tf_data)    { parse_file("recipe_output.tf.json") }

  def terraform_json_data(&block)
    data = JSON.parse(TerraformCompile.new(&block).to_tf_json)
    data
  end

  def terraform_attributes_data(&block)
    AttributePairs.new(&block).attr_kv_pairs
  end

  context "converting pseudo-Chef to Terraform data" do
    context "attributes" do
      it "converts an attributes block to a hash" do
        expected = { :foo => 23, :blargh => "a string" }
        actual = terraform_attributes_data do
          blargh "a string"
          foo 23
        end

        expect(actual).to eq(expected)
      end

      it "turns repeated complex attributes into arrays" do
        expected = {
          :derp=>"Allow all inbound traffic",
          :ingress=>
            {:from_port=>0, :to_port=>0, :protocol=>-1, :cidr_blocks=>["0.0.0.0/0"]},
          :egress=> [
            {:from_port=>0, :to_port=>0, :protocol=>-1, :cidr_blocks=>["0.0.0.0/0"]},
            {:cheese=>45,
              :lackadaisical=>true,
              :protocol=>22,
              :cidr_blocks=>["141.222.2.2/32", "fnord"]}]}
        actual = terraform_attributes_data do
          description "Allow all inbound traffic"
          ingress(from_port: 0, to_port: 0, protocol: -1, cidr_blocks: ["0.0.0.0/0"])
          egress(from_port: 0, to_port: 0, protocol: -1, cidr_blocks: ["0.0.0.0/0"])
          egress(cheese: 45, lackadaisical: true, protocol: 22, cidr_blocks: ["141.222.2.2/32", "fnord"])
        end
      end
    end

    context "full TF blocks" do
      it "parses my own TF recipe into TF data" do
        # it's much more natural to create our data structure with symbols, but then we have a deeply nested
        # structure with a mix of string and hash keys, and JSON parsing only returns one or the other... by
        # exporting and re-importing to/from JSON, we stringify all our keys, and the test is closer to real-
        # life conditions.
        actual = terraform_json_data do
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
        end

        expect(actual).to eq(my_tf_data)
      end

      it "parses a TF recipe into TF's sample data" do
        actual = terraform_json_data do
          provider "aws" do
            access_key "foo"
            secret_key "bar"
          end

          provider "do" do
            api_key "${var.foo}"
          end

          variable "foo" do
            default "bar"
            description "bar"
          end

          aws_instance "db" do
            security_groups ["${aws_security_group.firewall.*.id}"]
            VPC "foo"
            depends_on ["aws_instance.web"]
            provisioner [{ file: {source: "foo", destination: "bar"} }]
          end

          aws_instance "web" do
            ami "${var.foo}"
            security_groups [
                    "foo",
                    "${aws_security_group.firewall.foo}"
                ]
            network_interface(device_index: 0,
                              description: "Main network interface")
            provisioner(
                    file: {
                        source: "foo",
                        destination: "bar"
                    }
                )
          end

          aws_security_group "firewall" do
            count 5
          end

          output "web_ip" do
            value "${aws_instance.web.private_ip}"
          end

          provisioner "file" do
              source "conf/myapp.conf"
              destination "C:/App/myapp.conf"
              connection(
                  type: "winrm",
                  user: "Administrator",
                  password: "${var.admin_password}",
              )
          end

          tf_module "consul" do
            source "github.com/hashicorp/consul/terraform/aws"
            servers 5
          end

          atlas "chef/merp"
        end

        expect(actual).to eq(basic_tf_data)
      end

      # resource "aws_security_group" "allow_all" {
      #   name = "allow_all"
      #   description = "Allow all inbound traffic"

      #   ingress {
      #       from_port = 0
      #       to_port = 0
      #       protocol = "-1"
      #       cidr_blocks = ["0.0.0.0/0"]
      #   }

      #   egress {
      #       from_port = 0
      #       to_port = 0
      #       protocol = "-1"
      #       cidr_blocks = ["0.0.0.0/0"]
      #   }
      # }
      it "processes nested blocks like aws_security_group" do
        expected = {"resource"=>
          {"aws_security_group"=>
            {"allow_all"=> {
              "name"=>"security-group-name",
               "description"=>"Allow all inbound traffic",
               "ingress"=> {
                 "from_port"=>0,
                 "to_port"=>0,
                 "protocol"=>-1,
                 "cidr_blocks"=>["0.0.0.0/0"]},
               "egress"=> [
                 {"from_port"=>0,
                  "to_port"=>0,
                  "protocol"=>-1,
                  "cidr_blocks"=>["0.0.0.0/0"]},
                 {"from_port"=>45,
                  "to_port"=>true,
                  "protocol"=>22,
                  "cidr_blocks"=>["141.222.2.2/32", "fnord"]}
                ]
                }}}}

        actual = terraform_json_data do
          aws_security_group "allow_all" do
            name "security-group-name"
            description "Allow all inbound traffic"
            ingress(from_port: 0, to_port: 0, protocol: -1, cidr_blocks: ["0.0.0.0/0"])
            egress(from_port: 0, to_port: 0, protocol: -1, cidr_blocks: ["0.0.0.0/0"])
            egress(from_port: 45, to_port: true, protocol: 22, cidr_blocks: ["141.222.2.2/32", "fnord"])
          end
        end
        expect(actual).to eq(expected)
      end
    end
  end
end
