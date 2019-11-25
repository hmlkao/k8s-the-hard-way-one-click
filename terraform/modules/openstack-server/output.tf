output "instance_hostnames" {
  value = openstack_compute_instance_v2.instance.*.name
}

output "instance_ips" {
  value = openstack_compute_instance_v2.instance.*.access_ip_v4
}
