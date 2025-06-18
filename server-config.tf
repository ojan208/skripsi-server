provider "google" {
    project     = "extreme-battery-426200-u1"
    region		= "asia-southeast2"
}

resource "google_compute_instance" "master-server" {
    name            = "master-server"
    machine_type    = "e2-standard-2"
    zone            = "asia-southeast2-a"
    tags            = [ "minecraft" ]

    boot_disk {
        initialize_params {
          image = "projects/debian-cloud/global/images/debian-12-bookworm-v20250415"
          type = "pd-ssd"
		  size = 10
        }
    }

    network_interface {
		network = "default"
		access_config {
		  network_tier = "PREMIUM"
		}
    }

	# install git, java, and tcpdump
	metadata_startup_script = <<-EOF
	sudo apt-get update
	sudo apt-get install -y git default-jre tcpdump
	git clone https://github.com/ojan208/skripsi-docker-server.git /home/skripsi-docker-server
	sudo tcpdump -w /home/master-captured_packets.pcap tcp &
	cd /home/skripsi-docker-server/master
	nohup java -jar multipaper-master-2.12.3-all.jar &
	EOF
}

variable "zones" {
	type = list(string)
	default = [ 
		"southeast2",
		"south2",
		"southeast1",
		"east1",
	]
}

locals {
  worker = { for zone in var.zones : "worker-${zone}" => "asia-${zone}-a"}
}

resource "google_compute_instance" "worker-server" {
	for_each = local.worker
	name = each.key
	machine_type = "e2-standard-2"
	zone = each.value
	tags = [ "minecraft" ]

	boot_disk {
		initialize_params {
			image = "projects/debian-cloud/global/images/debian-12-bookworm-v20250415"
			type = "pd-ssd"
			size = 10
		}
  	}

	network_interface {
		network = "default"
		access_config {
			network_tier = "PREMIUM"
		}
	}

	# install git, java, and tcpdump
	metadata_startup_script = <<-EOF
	sudo apt-get update
	sudo apt-get install -y git default-jre tcpdump
	git clone https://github.com/ojan208/skripsi-docker-server.git /home/skripsi-docker-server
	sudo tcpdump -w /home/${ each.key }-captured_packets.pcap tcp &
	cd /home/skripsi-docker-server/worker 
	chmod +x run_server.sh
	nohup ./run_server.sh ${each.key} ${google_compute_instance.master-server.network_interface.0.network_ip}:35353 &
	EOF

	depends_on = [ 
		google_compute_instance.master-server
	]
}
