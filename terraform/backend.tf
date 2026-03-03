terraform {
  backend "s3" {
    bucket         = "070066739317-terraform-state"
    key            = "stacks/remote-dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
