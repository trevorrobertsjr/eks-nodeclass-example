resource "aws_iam_role" "custom_nodeclass_role" {
  name = "eks-t4g-nodeclass-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name    = "eks-t4g-nodeclass-role"
      Type    = "eks-nodeclass-role"
      Cluster = local.cluster_name
    }
  )
}

# Attach required policies for EKS worker nodes
resource "aws_iam_role_policy_attachment" "custom_nodeclass_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.custom_nodeclass_role.name
}

resource "aws_iam_role_policy_attachment" "custom_nodeclass_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.custom_nodeclass_role.name
}

resource "aws_iam_role_policy_attachment" "custom_nodeclass_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.custom_nodeclass_role.name
}

# VPC networking policy as well for the pod subnet functionality
resource "aws_iam_role_policy" "custom_nodeclass_vpc_policy" {
  name = "eks-t4g-nodeclass-vpc-policy"
  role = aws_iam_role.custom_nodeclass_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create instance profile for the role
resource "aws_iam_instance_profile" "custom_nodeclass_profile" {
  name = "eks-t4g-nodeclass-profile"
  role = aws_iam_role.custom_nodeclass_role.name

  tags = merge(
    local.common_tags,
    {
      Name    = "eks-t4g-nodeclass-profile"
      Cluster = local.cluster_name
    }
  )
}

# Create access entry for the custom NodeClass IAM role
resource "aws_eks_access_entry" "nodeclass_access_entry" {
  cluster_name      = local.cluster_name
  principal_arn     = aws_iam_role.custom_nodeclass_role.arn
  kubernetes_groups = []
  type             = "EC2"
}

resource "aws_eks_access_policy_association" "nodeclass_policy" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.custom_nodeclass_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.nodeclass_access_entry]
}

# Custom NodeClass for t4g instances with pod subnet configuration
resource "kubernetes_manifest" "custom_nodeclass" {
  manifest = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "NodeClass"
    metadata = {
      name = "t4g-nodeclass"
    }
    spec = {
      # Use the role NAME (not ARN)
      role = aws_iam_role.custom_nodeclass_role.name

      # Subnets for EC2 instances (nodes) - using tags for flexibility
      subnetSelectorTerms = [
        {
          tags = {
            "kubernetes.io/role/internal-elb" = "1"
          }
        }
      ]

      # Security groups for nodes
      securityGroupSelectorTerms = [
        {
          id = local.node_security_group_id
        }
      ]

      # Dedicated pod subnets - EKS Auto Mode will handle VPC CNI automatically
      podSubnetSelectorTerms = [
        {
          tags = {
            "kubernetes.io/role/cni" = "1"
          }
        }
      ]
      
      # Pod security groups (dedicated security group for pods)
      podSecurityGroupSelectorTerms = [
        {
          id = local.pod_security_group_id
        }
      ]
      
      # Let EKS Auto Mode manage networking automatically
      snatPolicy             = "Random"
      networkPolicy          = "DefaultAllow"
      networkPolicyEventLogs = "Disabled"

      # Ephemeral storage configuration optimized for t4g instances
      ephemeralStorage = {
        size       = "40Gi"
        iops       = 3000
        throughput = 125
      }

      # Tags for cost allocation and management
      tags = merge(
        local.common_tags,
        {
          NodeClass    = "t4g-nodeclass"
          InstanceType = "t4g-arm64"
          Purpose      = "general-workload"
        }
      )
    }
  }

  depends_on = [
    data.terraform_remote_state.eks_infrastructure,
    aws_eks_access_entry.nodeclass_access_entry,
    aws_iam_role.custom_nodeclass_role
  ]
}

# NodePool using the custom NodeClass
resource "kubernetes_manifest" "t4g_nodepool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "t4g-nodepool"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            nodepool-type = "t4g-arm64"
            billing-team  = local.project_name
            environment   = local.environment
          }
        }
        spec = {
          # Reference our custom NodeClass
          nodeClassRef = {
            group = "eks.amazonaws.com"
            kind  = "NodeClass"
            name  = "t4g-nodeclass"
          }

          # Requirements for t4g.small and t4g.medium only
          requirements = [
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = ["t4g.small", "t4g.medium"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["arm64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            },
            # Distribute across all available zones
            {
              key      = "topology.kubernetes.io/zone"
              operator = "In"
              values   = local.availability_zones
            }
          ]

          # Node termination settings
          terminationGracePeriod = "30s"
        }
      }

      # Resource limits for the NodePool
      limits = {
        cpu    = "100"   # 100 vCPUs total limit
        memory = "400Gi" # 400 GiB memory total limit
      }

      # Disruption settings for cost optimization
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "30s"
        # expireAfter = "72h"  # Uncomment to auto-expire nodes after 72 hours
      }
    }
  }

  depends_on = [
    kubernetes_manifest.custom_nodeclass
  ]
}

# Optional: Create a test deployment to verify the NodePool works
resource "kubernetes_manifest" "test_deployment" {
  count = var.create_test_deployment ? 1 : 0

  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "t4g-test-app"
      namespace = "default"
    }
    spec = {
      replicas = 2
      selector = {
        matchLabels = {
          app = "t4g-test-app"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "t4g-test-app"
          }
        }
        spec = {
          # Node selector to target our t4g NodePool
          nodeSelector = {
            "nodepool-type" = "t4g-arm64"
          }

          containers = [
            {
              name  = "nginx"
              image = "nginx:alpine"
              ports = [
                {
                  containerPort = 80
                }
              ]
              resources = {
                requests = {
                  cpu    = "100m"
                  memory = "128Mi"
                }
                limits = {
                  cpu    = "200m"
                  memory = "256Mi"
                }
              }
            }
          ]
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.t4g_nodepool
  ]
}