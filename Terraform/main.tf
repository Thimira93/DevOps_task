
module "network" {
  source = "./modules/network"
}

module "load_balancer" {
  source            = "./modules/load_balancer"
  public_subnet_ids = [module.network.public_subnet_1_id, module.network.public_subnet_2_id]
}
