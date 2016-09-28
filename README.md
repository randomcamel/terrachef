# terrachef
Write almost any Terraform configuration using code indistinguishable from Chef resources.

This should support anything Terraform supports; it doesn't rely on an explicit list of Terraform functionality, so when Terraform adds something, you can use it via Terrachef.

_(This was a fun Hack Day project, so while it works, it has gaps due to lack of real-world use. The gaps are really about me learning to use Terraform and applying that knowledge here; the part where a Chef recipe gets turned into Terraform JSON is pretty solid. If you want it to be better, please [let me know](https://github.com/randomcamel/terrachef/issues)._

## Future Work

Being tracked [here](https://github.com/randomcamel/terrachef/issues/1).

## Example

Terraform has its own DSL, but if you already know Chef, you should be able to use Chef! Or something that looks and feels like Chef.

**WARNING: You can use the normal Terraform directives everywhere, _EXCEPT_ for `module`: because `module` is a Ruby keyword, we use `tf_module` instead.**

```ruby
require "terrachef"

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

You can use Terraform variables, and just like in Terraform, to ensure ordering, you must add `depends_on` yourself. Pretty much anything Terraform can do can be expressed with Terrachef: everything is passed straight through to Terraform. (If it's not, please file a bug.) This is one of Terraform's long examples, converted to Terrachef.

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

  # EXCEPTION: since "module" is a Ruby keyword, we have to use "tf_module" here.
  tf_module "consul" do
    source "github.com/hashicorp/consul/terraform/aws"
    servers 5
  end

  output "web_ip" do
    value "${aws_instance.web.private_ip}"
  end

```
