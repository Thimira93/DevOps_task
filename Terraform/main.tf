module "network" {
  source = "./modules/network"
}

module "load_balancer" {
  source = "./modules/load_balancer"
}