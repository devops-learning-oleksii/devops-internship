output "server_node_public_ip" {
  value = module.ec2_instance["server-1"].public_ip
}
output "worker_1_public_ip" {
  value = module.ec2_instance["worker-1"].private_ip
}
output "worker_2_public_ip" {
  value = module.ec2_instance["worker-2"].private_ip
}
output "worker_3_public_ip" {
  value = module.ec2_instance["worker-3"].private_ip
}
output "DATABASE_ENDPOINT" {
  value = module.db.db_instance_address
}
