data "google_compute_network" "my-network" {
  name    = "producer-vpc"
  project = "mlops-448320"
}

data "google_compute_subnetwork" "my-subnetwork" {
  name    = "bastion-host-subnet"
  region  = "us-east1"
  project = "mlops-448320"
}

resource "google_workbench_instance" "default" {
  count = 2

  project  = "mlops-448320"
  name     = "workbench-instance-example-${count.index}"
  location = "us-east1-b"

  gce_setup {
    machine_type = "n1-standard-1"
    vm_image {
      project = "cloud-notebooks-managed"
      family  = "workbench-instances"
    }
    metadata = {
      idle-timeout-seconds = "600"
    }

    service_accounts {
      email = "mlops-sa@mlops-448320.iam.gserviceaccount.com"
    }

    network_interfaces {
      network = data.google_compute_network.my-network.id
      subnet  = data.google_compute_subnetwork.my-subnetwork.id
    }
	
    disable_public_ip = true
  }
}
