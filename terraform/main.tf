# Control plane

module "cp-dc2-01" {
  source = "./modules/openstack-server"

  name        = "khw-cp-dc2-01"
  region      = "RegionTwo"
  flavor_name = "m1.small"
  image_name  = "ubuntu-bionic-factory"
  ssh_key     = "oh-key"
}

module "cp-dc1-01" {
  source = "./modules/openstack-server"

  name        = "khw-cp-dc1-01"
  region      = "RegionOne"
  flavor_name = "m1.small"
  image_name  = "ubuntu-bionic-factory"
  ssh_key     = "oh-key"
}

module "cp-dc2-02" {
  source = "./modules/openstack-server"

  name        = "khw-cp-dc2-02"
  region      = "RegionTwo"
  flavor_name = "m1.small"
  image_name  = "ubuntu-bionic-factory"
  ssh_key     = "oh-key"
}

# Workers

module "worker-dc1-01" {
  source = "./modules/openstack-server"

  name        = "khw-worker-dc1-01"
  region      = "RegionOne"
  flavor_name = "m1.medium"
  image_name  = "ubuntu-bionic-factory"
  ssh_key     = "oh-key"
}

module "worker-dc2-01" {
  source = "./modules/openstack-server"

  name        = "khw-worker-dc2-01"
  region      = "RegionTwo"
  flavor_name = "m1.medium"
  image_name  = "ubuntu-bionic-factory"
  ssh_key     = "oh-key"
}
