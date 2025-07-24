output "server_node_private_ip" {
  value = module.compute.vms["server-node-1"].network_interface[0].network_ip
}

output "server_node_public_ip" {
  value = try(module.compute.vms["server-node-1"].network_interface[0].access_config[0].nat_ip, null)
}

output "worker_node_1_private_ip" {
  value = module.compute.vms["worker-node-1"].network_interface[0].network_ip
}

output "worker_node_2_private_ip" {
  value = module.compute.vms["worker-node-2"].network_interface[0].network_ip
}
