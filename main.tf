provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"

# If you have a self-signed cert
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "${var.vsphere_datacenter}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.vsphere_datastore}"
  datacenter_id = data.vsphere_datacenter.dc.id
}


data "vsphere_compute_cluster" "cluster" {
  name          = "${var.vsphere_compute_cluster}"
  datacenter_id = data.vsphere_datacenter.dc.id
}


data "vsphere_network" "network" {
  name          = "${var.vsphere_network}"
  datacenter_id = data.vsphere_datacenter.dc.id
}


# Retrieve template information on vsphere
data "vsphere_virtual_machine" "template" {
  name          = "${var.vsphere_virtual_machine}"
  datacenter_id = data.vsphere_datacenter.dc.id
}



resource "vsphere_virtual_machine" "vm" {

  connection {
    type     = "winrm"
    user     = "bnc\\Administrator"
    host     = self.default_ip_address
    password = "Heslo323"
    use_ntlm = true
    agent    = false
    insecure = true
    https    = true
   timeout  = "20s"
  
  }



provisioner "remote-exec" {
    when    = destroy
    on_failure = continue
    #command = "echo 'Destroy-time provisioner' > C:\\sources\\test.txt"
    #command = "Remove-Computer -UnjoinDomainCredential (New-Object System.Management.Automation.PSCredential ('administrator', (ConvertTo-SecureString 'Heslo323' -AsPlainText -Force))) -WorkgroupName 'Local' -Force"

    inline = [
      "cmd.exe /C Powershell.exe -ExecutionPolicy Bypass Remove-Computer -UnjoinDomainCredential $(New-Object System.Management.Automation.PSCredential ('administrator', (ConvertTo-SecureString 'Heslo323' -AsPlainText -Force))) -WorkgroupName 'Local' -Force",
      "echo 'Destroy-time provisioner' > C:\\sources\\test.txt",
    ]
}

 count = 2




  name             = format("NT-WEB%02d", count.index + 1)

  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  firmware = "efi"
  num_cpus         = 4
  num_cores_per_socket = 4
  memory           = 4096
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }
  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id


    customize {
	 windows_options {
	  computer_name = format("NT-WEB%02d", count.index + 1)

	  join_domain = "${var.domain_add_domain}"
	  domain_admin_user = "${var.domain_add_user}"
	  domain_admin_password = "${var.domain_add_password}"
	  organization_name = "${var.customize_company_name}"

	  admin_password = "${var.customize_local_admin_pwd}"
	  auto_logon     = true
	  auto_logon_count = 1


	run_once_command_list = [
		"cmd.exe /C Powershell.exe -ExecutionPolicy ByPass -File C:\\temp\\ConfigureRemotingForAnsible.ps1 -CertValidityDays 3650",
		"cmd.exe /C Powershell.exe -ExecutionPolicy Bypass Install-WindowsFeature -Name DNS -IncludeManagementTools",
		"cmd.exe /C Powershell.exe -ExecutionPolicy Bypass Add-DnsServerPrimaryZone -Name vmclab.local -ZoneFile vmclab.local.dns",
		"cmd.exe /C Powershell.exe -ExecutionPolicy Bypass Add-DnsServerResourceRecordA -Name mmdemo-host -ZoneName vmclab.local -AllowUpdateAny -IPv4Address 10.1.1.2",
		"cmd.exe /C Powershell.exe -ExecutionPolicy Bypass Add-DnsServerForwarder -IPAddress 10.1.1.1",
		"cmd.exe /C Powershell.exe -ExecutionPolicy Bypass net stop dns",
		"cmd.exe /C Powershell.exe -ExecutionPolicy Bypass net start dns"
]
 
          }
  #Time in minutes
  #timeout = 10
      network_interface {
        #ipv4_address = "10.130.251.60"
        ipv4_address = "10.130.251.${11 + count.index}"

        ipv4_netmask = 24
	dns_server_list = ["10.130.251.1","10.130.251.2"]
      }
      ipv4_gateway = "10.130.251.254"

  }
  


}


}















