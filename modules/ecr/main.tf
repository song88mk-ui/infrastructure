variable "repositories" {
  type = map(any)
}

resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name = each.key
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = var.repositories

  repository = aws_ecr_repository.this[each.key].name

  policy = <<POLICY
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Retain at least ${each.value.devImageCount} images tagged as ${each.value.devImagePrefix}",
      "selection": {
        "tagStatus": "tagged",
        "tagPatternList": ["${each.value.devImagePrefix}-*"],
        "countType": "imageCountMoreThan",
        "countNumber": ${each.value.devImageCount}
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Retain at least ${each.value.prodImageCount} images tagged as v*",
      "selection": {
        "tagStatus": "tagged",
        "tagPatternList": ["v*"],
        "countType": "imageCountMoreThan",
        "countNumber": ${each.value.prodImageCount}
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
      "description": "Retain at least 20 images tagged as pr*",
      "selection": {
        "tagStatus": "tagged",
        "tagPatternList": ["pr-*"],
        "countType": "imageCountMoreThan",
        "countNumber": 20
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
POLICY
}

