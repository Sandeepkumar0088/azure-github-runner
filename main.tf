provider "azurerm" {
  features {}
}
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
resource "azurerm_resource_group" "github_action" {
  name = "github_action_rg"
  location = "Central India"
}
resource "azurerm_virtual_network" "vnet" {
  name                = "github_action_vnet"
  location            = azurerm_resource_group.github_action.location
  resource_group_name = azurerm_resource_group.github_action.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "github_action_subnet"
  resource_group_name  = azurerm_resource_group.github_action.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_public_ip" "github_action" {
  name                = "github_action_pip"
  location            = azurerm_resource_group.github_action.location
  resource_group_name = azurerm_resource_group.github_action.name
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "github_action" {
  name                = "github_action_sg"
  location            = azurerm_resource_group.github_action.location
  resource_group_name = azurerm_resource_group.github_action.name

  # Allow ALL inbound traffic
  security_rule {
    name                       = "Allow-All-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"

    source_port_range          = "*"
    destination_port_range     = "*"

    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

  # Allow ALL outbound traffic
  security_rule {
    name                       = "Allow-All-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "jenkins" {

  name                = "github_action_nic"
  location            = azurerm_resource_group.github_action.location
  resource_group_name = azurerm_resource_group.github_action.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.aks.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.github_action.id
  }
}

resource "azurerm_network_interface_security_group_association" "github_action" {

  network_interface_id      = azurerm_network_interface.jenkins.id
  network_security_group_id = azurerm_network_security_group.github_action.id
}

resource "azurerm_linux_virtual_machine" "github_action" {
  name                = "github-action-vm"
  resource_group_name = azurerm_resource_group.github_action.name
  location            = azurerm_resource_group.github_action.location
  size                = "Standard_D4ls_v6"

  admin_username                  = "sandeep"
  admin_password                  = "Sandeep.,@0088"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.jenkins.id
  ]
  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "almalinux"
    offer     = "almalinux-x86_64"
    sku       = "9-gen2"
    version   = "latest"
  }
}

resource "null_resource" "jenkins" {

  depends_on = [
    azurerm_linux_virtual_machine.github_action
  ]

  connection {
    type     = "ssh"
    host     = azurerm_linux_virtual_machine.github_action.public_ip_address
    user     = "sandeep"
    password = "Sandeep.,@0088"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo dnf install -y podman python3-pip ansible-core",
      "sudo systemctl enable --now podman.socket",
      "ansible-galaxy collection install containers.podman",
      "ansible-pull -i localhost, -U https://github.com/Sandeepkumar0088/azure-github-runner.git runner.yml -e TOKEN=${var.TOKEN}"
    ]
  }
}
resource "null_resource" "permissions" {

  depends_on = [
    azurerm_linux_virtual_machine.github_action,
    null_resource.jenkins
  ]

  connection {
    type     = "ssh"
    host     = azurerm_linux_virtual_machine.github_action.public_ip_address
    user     = "sandeep"
    password = "Sandeep.,@0088"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 666 /run/podman/podman.sock",
      "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc",

      "sudo dnf install -y https://packages.microsoft.com/config/rhel/9.0/packages-microsoft-prod.rpm",

      "sudo dnf install -y azure-cli",
      # "sudo az vm identity assign --resource-group github_action_rg --name github-action-vm"
    ]
  }
}

variable "TOKEN" {}
variable "SUBSCRIPTION_ID" {
  default = "bb2e4b65-7863-4a64-99b2-cd7d29b73bd7"
}

resource "azurerm_role_assignment" "vm_contributor" {

  depends_on = [
    azurerm_linux_virtual_machine.github_action,
    azurerm_resource_group
  ]

  scope                = azurerm_resource_group.github_action.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_virtual_machine.github_action.identity[0].principal_id
}

resource "azurerm_role_assignment" "vm_contributor" {

  depends_on = [
    azurerm_linux_virtual_machine.github_action,
    null_resource.jenkins,
    null_resource.permissions
  ]

  scope                = "/subscriptions/${var.SUBSCRIPTION_ID}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_virtual_machine.github_action.identity[0].principal_id
}