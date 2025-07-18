resource "azurerm_resource_group" "assignment2" {
    name = "assignment-2"
    location = "EastUS"
  
}

resource "azurerm_virtual_network" "vnet-assignment2" {
  name                = "vnet-assignment2"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.assignment2.location
  resource_group_name = azurerm_resource_group.assignment2.name
}

resource "azurerm_subnet" "subnet-assignment2" {

    name                 = "subnet-assignment2"
    resource_group_name  = azurerm_resource_group.assignment2.name
    virtual_network_name = azurerm_virtual_network.vnet-assignment2.name
    address_prefixes     = ["10.0.1.0/24"]
}


resource "azurerm_public_ip" "pubip-assignment2" {
    name                = "public-ip-ass2"
    location            = azurerm_resource_group.assignment2.location
    resource_group_name = azurerm_resource_group.assignment2.name
    allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "nic-assignment2" {
    name                = "nic1"
    location            = azurerm_resource_group.assignment2.location
    resource_group_name = azurerm_resource_group.assignment2.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-assignment2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pubip-assignment2.id
  }
}
data "azurerm_key_vault" "kv" {
  name                = "vm-name"
  resource_group_name = azurerm_resource_group.assignment2.name
}

data "azurerm_key_vault_secret" "vm_password" {
  name         = "vm-secret"
  key_vault_id = data.azurerm_key_vault.kv.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "ubuntu-vm"
  resource_group_name = azurerm_resource_group.assignment2.name
  location            = azurerm_resource_group.assignment2.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  admin_password      = data.azurerm_key_vault_secret.vm_password.value
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.nic-assignment2.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y apache2",
      "echo '<h1>Hello from Terraform</h1>' | sudo tee /var/www/html/index.html"
    ]

    connection {
      type     = "ssh"
      user     = "azureuser"
      password = data.azurerm_key_vault_secret.vm_password.value
      host     = azurerm_public_ip.pip.ip_address
    }
  }
}