resource "azurerm_windows_virtual_machine" "testvm" {
  name                = "intune-test-vm"
  resource_group_name = var.rg
  location            = var.location
  size                = "Standard_D4s_v3"

  admin_username = var.username
  admin_password = var.password

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-21h2-pro"
    version   = "latest"
  }
}