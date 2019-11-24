data "openstack_images_image_v2" "coreos" {
  count = length(var.regions)

  name   = var.image_name
  region = element(var.regions, count.index)

  most_recent = true
}

resource "openstack_compute_instance_v2" "instance" {
  name   = var.name
  region = var.region

  image_id    = element(data.openstack_images_image_v2.coreos.*.id, index(var.regions, var.region))
  flavor_name = var.flavor_name

  key_pair = var.ssh_key["public"]
}
