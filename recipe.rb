require_relative "terraform"

terraform {
  provider "docker" do
    host "tcp://192.168.59.103:2376"
    cert_path "/Users/cdoherty/.boot2docker/certs/boot2docker-vm"
  end

  docker_container "foo" do
    image "ubuntu:latest"
    tf_name "foo"   # take this automatically from resource name.
  end

  # docker_image "ubuntu" do
  #   name "ubuntu:latest"
  # end
}

=begin
provider "docker" {
  host = "tcp://192.168.59.103:2376"
  cert_path = "/Users/cdoherty/.boot2docker/certs/boot2docker-vm"
}

resource "docker_container" "foo" {
  image = "${docker_image.ubuntu.latest}"
  name = "foo"
}
resource "docker_image" "ubuntu" {
  name = "ubuntu:latest"
}
=end
