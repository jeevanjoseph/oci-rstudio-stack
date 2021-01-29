
data "template_file" "theia-docker-compose" {
  template = file("${path.module}/scripts/theia.yaml")

  vars = {
    public_key_openssh  = tls_private_key.public_private_key_pair.public_key_openssh,
    mysql_root_password = var.mysql_root_password,
    nc_schema           = var.nc_schema,
    nc_db_user          = var.nc_db_user,
    nc_db_password      = var.nc_db_password
  }
}

data "template_file" "nginx-conf" {
  template = file("${path.module}/scripts/nginx.conf")
}


resource "oci_core_instance" "Theia" {
  availability_domain = local.availability_domain_name
  compartment_id      = var.compartment_ocid
  display_name        = "Theia"
  shape               = var.node_shape

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "primaryvnic"
    assign_public_ip = false
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.InstanceImageOCID.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.generate_public_ssh_key ? tls_private_key.public_private_key_pair.public_key_openssh : var.public_ssh_key
    user_data           = base64encode(templatefile("./scripts/setup-docker.yaml",{}))
  }

}

data "oci_core_vnic_attachments" "Theia_vnics" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.availability_domain_name
  instance_id         = oci_core_instance.Theia.id
}

data "oci_core_vnic" "Theia_vnic1" {
  vnic_id = data.oci_core_vnic_attachments.Theia_vnics.vnic_attachments[0]["vnic_id"]
}

data "oci_core_private_ips" "Theia_private_ips1" {
  vnic_id = data.oci_core_vnic.Theia_vnic1.id
}

resource "oci_core_public_ip" "Theia_public_ip" {
  compartment_id = var.compartment_ocid
  display_name   = "Theia_public_ip"
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.Theia_private_ips1.private_ips[0]["id"]
}

resource "null_resource" "Theia_provisioner" {
  depends_on = [oci_core_instance.Theia, oci_core_public_ip.Theia_public_ip]

  provisioner "file" {
    content     = data.template_file.theia-docker-compose.rendered
    destination = "/home/opc/theia.yaml"

    connection {
      type        = "ssh"
      host        = oci_core_public_ip.Theia_public_ip.ip_address
      agent       = false
      timeout     = "5m"
      user        = "opc"
      private_key = tls_private_key.public_private_key_pair.private_key_pem

    }
  }

  provisioner "file" {
    content     = data.template_file.nginx-conf.rendered
    destination = "/home/opc/nginx.conf"

    connection {
      type        = "ssh"
      host        = oci_core_public_ip.Theia_public_ip.ip_address
      agent       = false
      timeout     = "5m"
      user        = "opc"
      private_key = tls_private_key.public_private_key_pair.private_key_pem

    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = oci_core_public_ip.Theia_public_ip.ip_address
      agent       = false
      timeout     = "5m"
      user        = "opc"
      private_key = tls_private_key.public_private_key_pair.private_key_pem

    }

    inline = [
      "while [ ! -f /tmp/cloud-init-complete ]; do sleep 2; done",
      "docker run  --init --detach -p 80:3000 -v theia-workspace:/home/project:cached theiaide/theia:next"
    ]

  }
}



locals {
  availability_domain_name = var.availability_domain_name != null ? var.availability_domain_name : data.oci_identity_availability_domains.ADs.availability_domains[0].name
}
