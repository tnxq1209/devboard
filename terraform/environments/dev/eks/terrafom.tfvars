region             = "ap-south-1"
cluster_name       = "devboard-eks"
kubernetes_version = "1.37"

node_instance_types = ["c7i-flex.large"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3
