variable "enable_budget" {
  type        = bool
  default     = false
  description = "Whether to create a subscription consumption budget"
}

variable "budget_name" {
  type        = string
  default     = ""
  description = "Name of the consumption budget"
}

variable "subscription_id" {
  type        = string
  default     = ""
  description = "Subscription ID to scope the budget to"
}

variable "budget_amount" {
  type        = number
  default     = 0
  description = "Monthly budget amount in USD"
}

variable "budget_start_date" {
  type        = string
  default     = "2026-01-01T00:00:00Z"
  description = "Budget start date in RFC3339 format"
}

variable "budget_end_date" {
  type        = string
  default     = "2027-01-01T00:00:00Z"
  description = "Budget end date in RFC3339 format"
}

variable "contact_emails" {
  type        = list(string)
  default     = []
  description = "Email addresses for budget alert notifications"
}
