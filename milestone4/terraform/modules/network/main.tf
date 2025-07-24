resource "google_compute_network" "main" {
  name                    = "main-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name                     = "public-subnet"
  ip_cidr_range            = "10.100.0.0/24"
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "private" {
  name                     = "private-subnet"
  ip_cidr_range            = "10.100.1.0/24"
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "main-allow" {
  name    = "main-allow"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = flatten([var.public_tcp_ports, var.private_tcp_ports])
  }
  allow {
    protocol = "udp"
    ports    = flatten([var.public_udp_ports, var.private_udp_ports])
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["public", "private"]
}

resource "google_compute_router" "main" {
  name    = "main-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                                = "main-nat"
  router                              = google_compute_router.main.name
  region                              = var.region
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_endpoint_independent_mapping = true
}
