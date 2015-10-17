# terrachef
Write almost any Terraform configuration using code indistinguishable from Chef resources.

_(This was a Hack Day project, so at the moment it works more in principle than in practice. The gaps are really about me learning to use Terraform and applying that knowledge here; the part where a Chef recipe gets turned into Terraform JSON is pretty solid.)_


## Future Ideas

- [ ] Better/any `.tfstate` management.
- [x] Allow user to specify `:plan` vs. `:apply` and maybe make that useful. <strike>(As a temporary hack, setting the `TERRACHEF_NOOP` environment variable with run `terraform plan` instead of `terraform apply`.)</strike>
- [ ] Integration testing (e.g. actually running the `terraform_execute` resource).
- [ ] Package up for consumption.
- [x] Full and tested top-level `provisioner` support.
- [ ] Full and tested top-level `module` support.
- [ ] More `terraform` subcommands as resource actions.

## Example

Terraform has its own DSL, but if you already know Chef, you should be able to use Chef!

```ruby
require_relative "lib/terraform"

log "before Terraform"

terraform "my-terraform-block" do
  provider "docker" do
    host "tcp://192.168.59.103:2376"
    cert_path "/Users/cdoherty/.boot2docker/certs/boot2docker-vm"
  end

  docker_container "foo" do
    image "ubuntu:latest"
    name "running_container_name"
  end

  docker_image "ubuntu" do
    name "ubuntu:latest"
  end
end

log "after Terraform"
```

This gets compiled and run using Terraform's JSON format (which has feature parity with the DSL):

```json
{
  "provider": {
    "docker": {
      "host": "tcp://192.168.59.103:2376",
      "cert_path": "/Users/cdoherty/.boot2docker/certs/boot2docker-vm"
    }
  },
  "resource": {
    "docker_container": {
      "foo": {
        "image": "ubuntu:latest",
        "name": "running_container_name"
      }
    },
    "docker_image": {
      "ubuntu": {
        "name": "ubuntu:latest"
      }
    }
  }
}
```

Running the above Chef recipe gives:

```
Converging 3 resources
Recipe: @recipe_files::/Users/cdoherty/repos/terrachef/recipe.rb
  * log[before Terraform] action write

  * terraform_execute[my-terraform-block] action execute
    * file[/tmp/my-terraform-block.tf.json] action create (up to date)
    * execute[Terraform block 'my-terraform-block'] action run
      - execute terraform

  * log[after Terraform] action write


Running handlers:
Running handlers complete
Chef Client finished, 4/5 resources updated in 04 seconds
```

You can use Terraform variables, and just like in Terraform, to ensure ordering, you must add `depends_on` yourself. Pretty much anything Terraform can do can be expressed with Terrachef: everything is passed straight through to Terraform. (If it's not, please file a bug.)

```ruby  
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

  provisioner "file" do
      source "conf/myapp.conf"
      destination "C:/App/myapp.conf"
      connection(
          type: "winrm",
          user: "Administrator",
          password: "${var.admin_password}"
      )
  end

  output "web_ip" do
    value "${aws_instance.web.private_ip}"
  end

```
