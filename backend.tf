terraform { 
  cloud { 
    
    organization = "my-org" 

    workspaces { 
      name = "eks-cluster-workspace" 
    } 
  } 
}