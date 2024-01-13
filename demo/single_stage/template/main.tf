
locals { cfg = jsondecode(file("../config.json")) }

terraform {
  backend "local" {
    path = "{{ .cfg.terraform.backend.path }}"
  }
}

provider "aws" {
  region = local.cfg.aws.region
  default_tags { tags = {
      Terraform = "true"
      ThrowMeAway = "true"
  } }
}


data "aws_caller_identity" "this"  {}
locals { account_id = data.aws_caller_identity.this.account_id }

resource "aws_iam_role" "brian_testing_terraform_a" {
  name = "BrianTestingTerraformA"
    assume_role_policy = <<-EOT
      {
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": {
              "AWS": "arn:aws:iam::${local.account_id}:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
              "ArnLike": {
                "aws:PrincipalArn": "arn:aws:iam::${local.account_id}:role/aws-reserved/sso.amazonaws.com/eu-west-2/AWSReservedSSO_TestAccess_*"
              }
            }
          }
        ]
      }
    EOT

#    jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Action = "sts:AssumeRole"
#        Effect = "Allow"
#        Sid    = ""
#        Principal = {
#          Service = "NOTHINGec2.amazonaws.com"
#        }
#      },
#    ]
#  })
}

output "created_role" { value = aws_iam_role.brian_testing_terraform_a }

