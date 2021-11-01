locals {
  vnics_attachments = flatten([for x in data.oci_core_vnic_attachments.instance_vnics : x.vnic_attachments])
  # the mgmt vnic appears to be blank and other nics use the same name in module vm.
  # It could be the /vnicAttachments API, can be verified with OCI CLI `oci compute vnic-attachment list --compartment-id  $compartment_id`
  mgmt_vnic_ids   = [for x in local.vnics_attachments : x.vnic_id if x.display_name == ""]
  inside_vnic_ids = [for x in local.vnics_attachments : x.vnic_id if x.display_name == "asav-${var.inside_network}-vnic"]
}

data "oci_identity_availability_domain" "ad" {
  count          = length(var.instance_ids)
  compartment_id = var.tenancy_ocid
  ad_number      = var.vm_ads_number[count.index]
}

# Gets a list of VNIC attachments on the instance
data "oci_core_vnic_attachments" "instance_vnics" {
  count               = length(var.instance_ids)
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domain.ad[count.index].name
  instance_id         = var.instance_ids[count.index]
}

# https://registry.terraform.io/providers/hashicorp/oci/latest/docs/data-sources/core_vnic_attachments#vnic_attachments
# A bug? the vinc order returned from OCI API are non deterministic
# no big deal, we will loop through the data.oci_core_vnic_attachments.instance_vnics and find out the vnic ids. 
# We need the vnic id for provisioning oci_core_private_ips, which can be used as target_id for LB backend. 
data "oci_core_vnic" "mgmt_vnic" {
  count = length(var.instance_ids)
  #vnic_id = data.oci_core_vnic_attachments.instance_vnics[count.index].vnic_attachments[0]["vnic_id"]
  vnic_id = local.mgmt_vnic_ids[count.index]
}

data "oci_core_vnic" "inside_vnic" {
  count   = length(var.instance_ids)
  vnic_id = local.inside_vnic_ids[count.index]
}

data "oci_core_private_ips" "mgmt_subnet_private_ip" {
  count   = length(var.instance_ids)
  vnic_id = data.oci_core_vnic.mgmt_vnic[count.index].id
}


data "oci_core_private_ips" "inside_subnet_private_ip" {
  count   = length(var.instance_ids)
  vnic_id = data.oci_core_vnic.inside_vnic[count.index].id
}

############################
## External Load Balancer ##
############################

resource "oci_network_load_balancer_network_load_balancer" "external_nlb" {
  compartment_id = var.compartment_id
  subnet_id      = var.networks_map[var.mgmt_network].subnet_id

  is_preserve_source_destination = false
  display_name                   = "CiscoExternalPublicNLB"
  is_private                     = false
}

resource "oci_network_load_balancer_backend_set" "external-lb-backend" {
  name                     = "external-lb-backend"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.external_nlb.id
  policy                   = "FIVE_TUPLE"
  health_checker {
    port     = "22"
    protocol = "TCP"
  }
}

resource "oci_network_load_balancer_listener" "external-lb-listener" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.external_nlb.id
  name                     = "firewall-untrust"
  default_backend_set_name = oci_network_load_balancer_backend_set.external-lb-backend.name
  port                     = var.service_port
  protocol                 = "TCP"
}

resource "oci_network_load_balancer_backend" "external-public-lb-ends" {
  count                    = length(var.instance_ids)
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.external_nlb.id
  backend_set_name         = oci_network_load_balancer_backend_set.external-lb-backend.name
  port                     = var.service_port

  #Optional
  #target_id = var.instance_ids[count.index]
  #target_id =  oci_core_private_ip.export_asa-mgmt-vnic.id
  target_id = data.oci_core_private_ips.mgmt_subnet_private_ip[count.index].private_ips[0]["id"]
}


# ############################
# ## Internal Load Balancer ##
# ############################

resource "oci_network_load_balancer_network_load_balancer" "internal_nlb" {
  compartment_id                 = var.compartment_id
  subnet_id                      = var.networks_map[var.inside_network].subnet_id
  is_preserve_source_destination = false
  display_name                   = "CiscoInternalNLB"
  is_private                     = true
}

resource "oci_network_load_balancer_backend_set" "internal-lb-backend" {
  name                     = "internal-lb-backend"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.internal_nlb.id
  policy                   = "FIVE_TUPLE"
  health_checker {
    port     = "22"
    protocol = "TCP"
  }
}

resource "oci_network_load_balancer_listener" "internal-lb-listener" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.internal_nlb.id
  name                     = "firewall-trust"
  default_backend_set_name = oci_network_load_balancer_backend_set.internal-lb-backend.name
  port                     = "0"
  protocol                 = "TCP"
}

resource "oci_network_load_balancer_backend" "internal-lb-ends" {
  count                    = length(var.instance_ids)
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.internal_nlb.id
  backend_set_name         = oci_network_load_balancer_backend_set.internal-lb-backend.name
  port                     = "0"
  target_id                = data.oci_core_private_ips.inside_subnet_private_ip[count.index].private_ips[0]["id"]
}




# resource "oci_network_load_balancer_backend" "external-public-lb-ends02" {
#   network_load_balancer_id = oci_network_load_balancer_network_load_balancer.external_nlb.id
#   backend_set_name         = oci_network_load_balancer_backend_set.external-lb-backend.name
#   port                     = var.service_port

#   #Optional
#   ip_address = var.backend_ip_address
# }


# resource "google_compute_forwarding_rule" "asa-ext-fr" {
#   name                  = "asa-ext-fr-${random_string.suffix.result}"
#   project               = var.project_id
#   region                = var.region
#   load_balancing_scheme = "EXTERNAL"
#   port_range            = var.service_port
#   backend_service       = google_compute_region_backend_service.asa-region-be-ext.id
# }


# resource "google_compute_region_backend_service" "asa-region-be-ext" {
#   name          = "asa-region-be-ext-${random_string.suffix.result}"
#   project       = var.project_id
#   region        = var.region
#   health_checks = [google_compute_region_health_check.ssh-health-check.self_link]

#   load_balancing_scheme = "EXTERNAL"
#   protocol              = "TCP"
#   port_name             = "http"
#   timeout_sec           = 10


#   dynamic "backend" {
#     for_each = toset(local.backends)
#     iterator = backend
#     content {
#       balancing_mode = "CONNECTION"
#       description    = "Terraform managed instance group for ASA."
#       group          = backend.key
#     }
#   }
# }

# ############################
# ## Health Check ##
# ############################
# resource "google_compute_region_health_check" "ssh-health-check" {
#   name        = "ssh-health-check-${random_string.suffix.result}"
#   description = "Terraform managed."
#   project     = var.project_id
#   region      = var.region

#   timeout_sec         = 5
#   check_interval_sec  = 15
#   healthy_threshold   = 4
#   unhealthy_threshold = 5

#   tcp_health_check {
#     port = "22"
#   }
# }


# ############################
# ## Internal Load Balancer ##
# ############################

# resource "google_compute_forwarding_rule" "asa-int-fr" {
#   count = var.use_internal_lb ? 1 : 0

#   name                  = "asa-int-fr-${random_string.suffix.result}"
#   project               = var.project_id
#   region                = var.region
#   ip_protocol           = "TCP"
#   load_balancing_scheme = "INTERNAL"
#   network_tier          = "PREMIUM"
#   allow_global_access   = var.allow_global_access

#   network    = var.networks_map[var.inside_network].network_self_link
#   subnetwork = var.networks_map[var.inside_network].subnet_self_link
#   # service_label         = var.service_label
#   backend_service = google_compute_region_backend_service.asa-region-be-int.id
#   #all_ports             = true
#   ports = [var.service_port]
# }


# resource "google_compute_region_backend_service" "asa-region-be-int" {
#   name          = "asa-region-be-int-${random_string.suffix.result}"
#   project       = var.project_id
#   region        = var.region
#   health_checks = [google_compute_region_health_check.ssh-health-check.self_link]

#   load_balancing_scheme = "INTERNAL"
#   protocol              = "TCP"
#   # network is needed for ILB
#   network = var.networks_map[var.inside_network].network_self_link

#   dynamic "backend" {
#     for_each = toset(local.backends)
#     iterator = backend
#     content {
#       balancing_mode = "CONNECTION"
#       description    = "Terraform managed instance group for ASA."
#       group          = backend.key
#     }
#   }
# }