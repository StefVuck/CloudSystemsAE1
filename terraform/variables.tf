variable "aws_region" {
  default = "eu-west-2"
}
variable "gcp_credentials_file" {
  description = "Path to the GCP service account key file"
  type        = string
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP Project ID"
}

variable "gcp_region" {
  default = "europe-west2"
}

variable "vm_username" {
  default = "cloudsys"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
}

variable "instance_count" {
  description = "Number of instances per cloud provider"
  default     = 3
}

variable "app_binary_url" {
  description = "URL to the compiled Go binary"
}

# AWS Resources
resource "aws_instance" "performance_test" {
  count         = var.instance_count
  ami           = "ami-0505148b3591e4c07"  # Ubuntu 22.04 LTS in eu-west-2
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ssh_key.key_name

  user_data = templatefile("${path.module}/scripts/setup.sh", {
    APP_BINARY_URL = var.app_binary_url
  })

  tags = {
    Name = "performance-test-aws-${count.index + 1}"
  }

  vpc_security_group_ids = [aws_security_group.allow_http.id]
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "performance-test-key"
  public_key = var.ssh_public_key
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# GCP Resources
resource "google_compute_firewall" "allow_http" {
  name    = "allow-performance-test"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["performance-test"]
}

resource "google_compute_instance" "performance_test" {
  count        = var.instance_count
  name         = "performance-test-gcp-${count.index + 1}"
  machine_type = "e2-micro"
  zone         = "${var.gcp_region}-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.vm_username}:${var.ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/scripts/setup.sh", {
    APP_BINARY_URL = var.app_binary_url
  })
  
  tags = ["performance-test"]
}

variable "azure_resource_group" {
  description = "Name of existing Azure resource group"
  type        = string
}

variable "azure_location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "ukwest"  # or whatever region your resource group is in
}

# Use data source to reference existing resource group
data "azurerm_resource_group" "performance_test" {
  name = var.azure_resource_group
}

resource "azurerm_virtual_network" "main" {
  name                = "performance-test-network"
  address_space       = ["10.0.0.0/16"]
  location           = data.azurerm_resource_group.performance_test.location
  resource_group_name = data.azurerm_resource_group.performance_test.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.performance_test.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_linux_virtual_machine" "performance_test" {
  count               = var.instance_count
  name                = "performance-test-azure-${count.index + 1}"
  resource_group_name = data.azurerm_resource_group.performance_test.name
  location            = data.azurerm_resource_group.performance_test.location
  size                = "Standard_B1s"
  admin_username      = var.vm_username

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  admin_ssh_key {
    username   = var.vm_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/scripts/setup.sh", {
    APP_BINARY_URL = var.app_binary_url
  }))
}

# Create Network Security Group
resource "azurerm_network_security_group" "performance_test" {
  name                = "performance-test-nsg"
  location            = data.azurerm_resource_group.performance_test.location
  resource_group_name = data.azurerm_resource_group.performance_test.name

  security_rule {
    name                       = "AllowPerformanceTest"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range         = "*"
    destination_port_range    = "8080"
    source_address_prefix     = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "main" {
  count               = var.instance_count
  name                = "performance-test-nic-${count.index + 1}"
  location            = data.azurerm_resource_group.performance_test.location
  resource_group_name = data.azurerm_resource_group.performance_test.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }
}

# Associate NSG with network interfaces
resource "azurerm_network_interface_security_group_association" "main" {
  count                     = var.instance_count
  network_interface_id      = azurerm_network_interface.main[count.index].id
  network_security_group_id = azurerm_network_security_group.performance_test.id
}

resource "azurerm_public_ip" "pip" {
  count               = var.instance_count
  name                = "performance-test-ip-${count.index + 1}"
  resource_group_name = data.azurerm_resource_group.performance_test.name
  location            = data.azurerm_resource_group.performance_test.location
  allocation_method   = "Static"
  sku = "Standard"
}
