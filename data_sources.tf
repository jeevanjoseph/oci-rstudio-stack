data "oci_core_images" "InstanceImageOCID" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.instance_os
  operating_system_version = var.linux_os_version
  shape = var.node_shape
  filter {
    name   = "display_name"
    values = ["^.*Oracle[^G]*$"]
    regex  = true
  }
}

data "oci_identity_availability_domains" "ADs" {

  compartment_id = var.compartment_ocid

}

data "oci_core_shapes" "matched_shapes" {
  compartment_id           = var.compartment_ocid
  availability_domain      = local.availability_domain_name

  # filter{
  #   name = "name"
  #   values = local.compute_flexible_shapes
  # }

  filter{
    name = "name"
    values = [local.flexible_shape_regex]
    regex= true
  }
}
