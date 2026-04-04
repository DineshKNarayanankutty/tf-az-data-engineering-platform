locals {
  prefix = lower(join("-", compact([var.environment, var.project])))
}
