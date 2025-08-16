terraform {
  backend "s3" {
    bucket         = "tf-state-raymondz-ap-southeast-2"
    key            = "terra-deploy/prod/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
