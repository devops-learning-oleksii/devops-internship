locals {
  expanded_instances = flatten([
    for inst in var.instances : [
      for i in range(lookup(inst, "count", 1)) : merge(
        inst,
        { instance_id = "${inst.name}-${i + 1}" }
      )
    ]
  ])
}

resource "google_compute_instance" "vm" {
  for_each     = { for inst in local.expanded_instances : inst.instance_id => inst }
  name         = each.value.instance_id
  machine_type = each.value.machine_type
  zone         = var.zone

  tags = [each.value.public ? "public" : "private"]

  boot_disk {
    initialize_params {
      image = each.value.image
    }
  }

  network_interface {
    network    = var.network_id
    subnetwork = each.value.public ? var.public_subnet_id : var.private_subnet_id

    dynamic "access_config" {
      for_each = each.value.public ? [1] : []
      content {}
    }
  }

  metadata = {
    ssh-keys = "${each.value.ssh_user}:${each.value.ssh_pubkey}"
  }
}
