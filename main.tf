
locals {
  url_prefix             = "https://www.googleapis.com/compute/v1"
  region                 = "us-central1" # only if neither region nor zone were specified
  machine_type           = "e2-micro"    # because it's the cheapest
  os_project             = "debian-cloud"
  os                     = "debian-11" # GCP default as of 2023
  service_account_scopes = ["compute-rw", "storage-rw", "logging-write", "monitoring"]
  metadata = {
    enable-osconfig         = "true"
    enable-guest-attributes = "true"
  }
  region_codes = {
    northamerica-northeast1 = "nane1"
    northamerica-northeast2 = "nane2"
    us-central1             = "usce1"
    us-east1                = "usea1"
    us-east4                = "usea4"
    us-east5                = "usea5"
    us-west1                = "uswe1"
    us-west2                = "uswe2"
    us-west3                = "uswe3"
    us-west4                = "uswe4"
    us-south1               = "usso1"
    europe-west1            = "euwe1"
    europe-west2            = "euwe2"
    europe-west3            = "euwe3"
    europe-west4            = "euwe4"
    australia-southeast1    = "ause1"
    australia-southeast2    = "ause2"
    asia-northeast1         = "asne1"
    asia-northeast2         = "asne2"
    asia-southeast1         = "asse1"
    asia-southeast2         = "asse2"
    asia-east1              = "asea1"
    asia-east2              = "asea2"
    asia-south1             = "asso1"
    asia-south2             = "asso2"
    southamerica-east1      = "saea1"
    me-central1             = "mece1"
  }
}


