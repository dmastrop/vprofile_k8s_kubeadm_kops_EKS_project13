# Variables

#CLUSTER_NAME=vprofile-eks-cluster
CLUSTER_NAME=vprofile-eksctl-cluster-project13
#REGION=us-east-2
REGION=us-east-1

# These are the worker nodes
NODE_NAME=Linux-nodes
# This is the SSH public key name. Keypair needs to be created with this name
# This key can be used to log into the worker node
KEY_NAME=vprofile-eks-key

# Set AWS credentials before script execution through aws configure

aws sts get-caller-identity >> /dev/null
if [ $? -eq 0 ]
then
  echo "Credentials tested, proceeding with the cluster creation."

  # Creation of EKS cluster
  # Autoscaling 1 to 4
  # version 1.20 is deprecated. Try running with 1.23
  eksctl create cluster \
  --name $CLUSTER_NAME \
  --version 1.23 \
  --region $REGION \
  --nodegroup-name $NODE_NAME \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --node-type t3.micro \
  --node-volume-size 8 \
  --ssh-access \
  --ssh-public-key $KEY_NAME \
  --managed
  if [ $? -eq 0 ]
  then
    echo "Cluster Setup Completed with eksctl command."
  else
    echo "Cluster Setup Failed while running eksctl command."
  fi
else
  echo "Please run aws configure & set right credentials."
  echo "Cluster setup failed."
fi

