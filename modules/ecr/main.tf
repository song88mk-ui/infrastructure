variable "repositories" {
  type = map(any)
}

variable "tags" {
  type = map(string)
}

resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name = each.key
  tags = var.tags
}

locals {
  defaultDevImageCount  = 15
  defaultProdImageCount = 30
  defaultDevImagePrefix = "main-sha"
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = var.repositories

  repository = aws_ecr_repository.this[each.key].name

  policy = <<POLICY
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Retain at least ${lookup(each.value, "devImageCount", local.defaultDevImageCount)} images tagged as ${lookup(each.value, "devImagePrefix", local.defaultDevImagePrefix)}",
      "selection": {
        "tagStatus": "tagged",
        "tagPatternList": ["${lookup(each.value, "devImagePrefix", local.defaultDevImagePrefix)}*"],
        "countType": "imageCountMoreThan",
        "countNumber": ${lookup(each.value, "devImageCount", local.defaultDevImageCount)}
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Retain at least ${lookup(each.value, "prodImageCount", local.defaultProdImageCount)} images tagged as v*",
      "selection": {
        "tagStatus": "tagged",
        "tagPatternList": ["v*"],
        "countType": "imageCountMoreThan",
        "countNumber": ${lookup(each.value, "prodImageCount", local.defaultProdImageCount)}
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
      "description": "Retain at least 5 images tagged as pr*",
      "selection": {
        "tagStatus": "tagged",
        "tagPatternList": ["pr-*"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
POLICY
}

