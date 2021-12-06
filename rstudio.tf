
data "template_file" "theia-docker-compose" {
  template = file("${path.module}/scripts/rstudio.yaml")

  vars = {
    public_key_openssh  = tls_private_key.public_private_key_pair.public_key_openssh,
    rstudio_user          = var.rstudio_user,
    rstudio_password      = var.rstudio_password
  }
}



resource "oci_core_instance" "RStudio" {
  availability_domain = local.availability_domain_name
  compartment_id      = var.compartment_ocid
  display_name        = "RStudio"
  shape               = local.instance_shape

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

data "oci_core_vnic_attachments" "RStudio_vnics" {
  compartment_id      = var.compartment_ocid
  availability_domain = local.availability_domain_name
  instance_id         = oci_core_instance.RStudio.id
}

data "oci_core_vnic" "RStudio_vnic1" {
  vnic_id = data.oci_core_vnic_attachments.RStudio_vnics.vnic_attachments[0]["vnic_id"]
}

data "oci_core_private_ips" "RStudio_private_ips1" {
  vnic_id = data.oci_core_vnic.RStudio_vnic1.id
}

resource "oci_core_public_ip" "RStudio_public_ip" {
  compartment_id = var.compartment_ocid
  display_name   = "RStudio_public_ip"
  lifetime       = "RESERVED"
  private_ip_id  = data.oci_core_private_ips.RStudio_private_ips1.private_ips[0]["id"]
}

resource "null_resource" "RStudio_provisioner" {
  depends_on = [oci_core_instance.RStudio, oci_core_public_ip.RStudio_public_ip]

  provisioner "file" {
    content     = data.template_file.theia-docker-compose.rendered
    destination = "/home/opc/rstudio.yaml"

    connection {
      type        = "ssh"
      host        = oci_core_public_ip.RStudio_public_ip.ip_address
      agent       = false
      timeout     = "5m"
      user        = "opc"
      private_key = tls_private_key.public_private_key_pair.private_key_pem

    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = oci_core_public_ip.RStudio_public_ip.ip_address
      agent       = false
      timeout     = "5m"
      user        = "opc"
      private_key = tls_private_key.public_private_key_pair.private_key_pem

    }

    inline = [
      "while [ ! -f /tmp/cloud-init-complete ]; do sleep 2; done",
      "docker-compose -f /home/opc/rstudio.yaml up -d"
    ]

  }
}



locals {
  availability_domain_name = var.availability_domain_name != null ? var.availability_domain_name : data.oci_identity_availability_domains.ADs.availability_domains[0].name
  instance_shape             = var.instance_shape != null ? var.instance_shape : data.oci_core_shapes.matched_shapes.shapes[0].name
  flexible_shape_regex       = "VM.Standard.E[3-9].Flex"
  is_flexible_instance_shape = length(regexall("VM.Standard.E[0-9].Flex", local.instance_shape)) > 0
}
