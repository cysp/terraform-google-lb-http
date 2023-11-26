/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

module "load_balancer" {
  source = "../../"

  name    = "mutual-tls-lb"
  project = var.project_id

  server_tls_policy = google_network_security_server_tls_policy.mutual-tls

  backends = {
    default = {
      protocol                        = "HTTP"
      port                            = 80
      port_name                       = "http"
      timeout_sec                     = 30
      connection_draining_timeout_sec = 0
      enable_cdn                      = false

      health_check = {
        check_interval_sec  = 15
        timeout_sec         = 15
        healthy_threshold   = 4
        unhealthy_threshold = 4
        request_path        = "/api/health"
        port                = 443
        logging             = true
      }

      log_config = {
        enable = false
      }

      # leave blank, NEGs are dynamically added to the lb via autoneg
      groups = []

      iap_config = {
        enable = false
      }
    }
  }
}

resource "google_certificate_manager_trust_config" "mutual-tls" {
  name     = "mutual-tls"
  location = "global"

  trust_stores {
    trust_anchors {
      pem_certificate = file("./mutual-tls-ca.pem")
    }
  }
}

resource "google_network_security_server_tls_policy" "mutual-tls" {
  provider = google-beta

  name     = "mutual-tls"
  location = "global"

  allow_open = false

  mtls_policy {
    client_validation_mode         = "REJECT_INVALID"
    client_validation_trust_config = google_certificate_manager_trust_config.mutual-tls.id
  }
}
