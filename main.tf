terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

# Create a Azure Resourcegroup
resource "azurerm_resource_group" "Dev-Environment" {
  name     = "Dev-Environment"
  location = "australiaeast"
}

## Create a Virtual network and subnets

resource "azurerm_virtual_network" "Dev-VN" {
  name                = "Dev-VirtualNetwork"
  location            = azurerm_resource_group.Dev-Environment.location
  resource_group_name = azurerm_resource_group.Dev-Environment.name
  address_space       = ["10.122.0.0/16"]



  tags = {
    environment = "Dev-VN"
  }
}

## Create a subnet
resource "azurerm_subnet" "Dev-Public-subnet" {
  name                 = "Dev-Public-subnet"
  resource_group_name  = azurerm_resource_group.Dev-Environment.name
  virtual_network_name = azurerm_virtual_network.Dev-VN.name
  address_prefixes     = ["10.122.1.0/24"]

}

## Create a network security group

resource "azurerm_network_security_group" "Dev-NSG" {
  name                = "Dev-NSG"
  location            = azurerm_resource_group.Dev-Environment.location
  resource_group_name = azurerm_resource_group.Dev-Environment.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}


# Create a public IP
resource "azurerm_public_ip" "Dev-Publicip" {
  name                = "Dev-Public-ip"
  resource_group_name = azurerm_resource_group.Dev-Environment.name
  location            = azurerm_resource_group.Dev-Environment.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Dev"
  }
}
# Create network interface
resource "azurerm_network_interface" "Dev-NIC" {
  name                = "Devlopment-nic"
  location            = azurerm_resource_group.Dev-Environment.location
  resource_group_name = azurerm_resource_group.Dev-Environment.name

  ip_configuration {
    name                          = "dev-nic"
    subnet_id                     = azurerm_subnet.Dev-Public-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.Dev-Publicip.id
  }
  tags = {
    environment = "dev"
  }
}

## create a Ubuntu virtual machine
resource "azurerm_linux_virtual_machine" "Dev-vm" {
  name                  = "dev-vm"
  resource_group_name   = azurerm_resource_group.Dev-Environment.name
  location              = azurerm_resource_group.Dev-Environment.location
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.Dev-NIC.id]

  custom_data = filebase64("customedata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/devkey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}