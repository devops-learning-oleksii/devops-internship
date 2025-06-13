locals {
  dump_filename = basename(var.database_dump_file)
}

# Copy dump file to EC2 instance
resource "null_resource" "copy_dump" {
  provisioner "local-exec" {
    command = "scp ${var.database_dump_file} ${var.ec2_instance}:~/"
  }
}

# Restore dump on the database
resource "null_resource" "restore_dump" {
  depends_on = [null_resource.copy_dump]

  provisioner "remote-exec" {
    connection {
      host        = var.ec2_instance
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.ssh_key_path)
    }

    inline = [
      "PGPASSWORD=${var.db_password} psql -h ${var.db_endpoint} -U ${var.db_username} -d ${var.db_name} -f ~/${local.dump_filename}"
    ]
  }
}
