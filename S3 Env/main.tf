provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

module "multi_region_app" {
  source   = "../modules/multi-region-app"
  app_name = "ovr-global-app"

  # The explicit wiring: matching the module's demands to your local aliases
  providers = {
    aws.primary = aws.east
    aws.replica = aws.west
  }
}