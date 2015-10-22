require_relative "lib/terrachef"

log "before Terraform"

terraform "my-terraform-block" do

  refresh false

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

log "after Terraform"
