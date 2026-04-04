resource "azurerm_consumption_budget_subscription" "main" {
  count           = var.enable_budget ? 1 : 0
  name            = var.budget_name
  subscription_id = var.subscription_id
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = var.budget_start_date
    end_date   = var.budget_end_date
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = var.contact_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    contact_emails = var.contact_emails
  }
}
