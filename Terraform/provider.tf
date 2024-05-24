provider "aws" {
  region = "us-west-1" # Update with your desired region
}

#terraform {
#    backend "s3"{
#        bucket = "s3statebackend0071"
#        dynamodb_table = "state-lock"
#        key = "global/mystatefile/terraform.tfstate"
#        region = "us-west-1"
#        encrypt = "true"
#    }
#}