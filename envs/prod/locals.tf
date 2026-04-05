locals {
  prefix = "${var.project}-${var.environment}"
  tags = {
    environment = var.environment
    project     = var.project
    owner       = var.owner
    cost_center = var.cost_center
    managed_by  = "terraform"
  }
}
