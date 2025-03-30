module "lab01-prod" {
  source = "./prod/labs/lab01"
  # ...
}

module "lab02-prod" {
  source = "./prod/labs/lab02"
  # ...
}

module "lab03-prod" {
  source = "./prod/labs/lab03"
  # ...
}

module "lab01-nonprod" {
  source = "./nonprod/labs/lab01"
  # ...
}

module "lab02-nonprod" {
  source = "./nonprod/labs/lab02"
  # ...
}

module "lab03-nonprod" {
  source = "./nonprod/labs/lab03"
  # ...
}
