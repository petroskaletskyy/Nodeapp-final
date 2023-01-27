provider "aws" {
  region = var.region
}

#-------------------VPC--------------------

#create vpc
resource "aws_vpc" "main" {
  cidr_block             = var.vpc_cidr
  enable_dns_hostnames   = true
  enable_dns_support     = true

  tags = {
    Name                 = "${var.project}-main-vpc"
  }
}

#----------------Subnets-------------------

#creating Public subnet
resource "aws_subnet" "public" {
  
  vpc_id                    = aws_vpc.main.id
  cidr_block                = cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, count.index)
  availability_zone         = data.aws_availability_zones.available.names[count.index]
  count                     = var.availability_zones_count
  map_public_ip_on_launch   = "true"
  
  tags = {
    Name                    = "${var.project}-public-sub"
  }
}

# Creating Private subnet
resource "aws_subnet" "private" {
  
  vpc_id                    = aws_vpc.main.id
  cidr_block                = cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, count.index + var.availability_zones_count)
  availability_zone         = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch   = "false"
  count                     = var.availability_zones_count 
  
  tags = {
    Name                    = "${var.project}-private-sub"
  }
}

resource "aws_db_subnet_group" "mysql_db_subnet_group" {
  name = "${var.project}-mysql-db-subnet-group"
  description = "DB subnet group"
  subnet_ids = aws_subnet.private[*].id
}

#--------------------------Internet Gateway------------------------

resource "aws_internet_gateway" "my_vpc_igw" {

  vpc_id        = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-igw"
  }

  depends_on    = [aws_vpc.main]
}

# Creating an Route Table for the public subnet!
resource "aws_route_table" "my_vpc_eu_west_1a_public" {

  vpc_id        = aws_vpc.main.id

  route {
    cidr_block  = "0.0.0.0/0"
    gateway_id  = aws_internet_gateway.my_vpc_igw.id
  }

  tags = {
    Name        = "${var.project}-default-rt"
  }
}

# Creating a resource for the Route Table Association!
resource "aws_route_table_association" "internet_access" {
  count = var.availability_zones_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.my_vpc_eu_west_1a_public.id
}

#--------------------------NAT Gateway------------------------------

#create elastic ip
resource "aws_eip" "ip" {
  vpc           = "true"  
  depends_on    = [
    aws_internet_gateway.my_vpc_igw
  ]

  tags = {
    Name        = "${var.project}-ngw-ip"
  }
}

#create NAT-gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id   = aws_eip.ip.id
  subnet_id       = aws_subnet.public[0].id

  tags = {
    Name          = "${var.project}-ngw"
  }
}

resource "aws_route" "main" {
  route_table_id = aws_vpc.main.default_route_table_id
  nat_gateway_id = aws_nat_gateway.nat_gateway.id
  destination_cidr_block = "0.0.0.0/0"
}

#-------------------------------Security Group---------------------------

# Security group for public subnet
resource "aws_security_group" "public_sg" {
  name   = "${var.project}-public-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-public-sg"
  }
}

# Security group traffic rules
resource "aws_security_group_rule" "sg_ingress_public_80" {
  security_group_id = aws_security_group.public_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "sg_egress_public" {
  security_group_id = aws_security_group.public_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Security group for data plane
resource "aws_security_group" "data_plane_sg" {
  name   = "${var.project}-worker-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-worker-sg"
  }
}

# Security group traffic rules
resource "aws_security_group_rule" "nodes" {
  description       = "Allow nodes to communicate with each other"
  security_group_id = aws_security_group.data_plane_sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 0), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 1), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])
}

resource "aws_security_group_rule" "nodes_inbound" {
  description       = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  security_group_id = aws_security_group.data_plane_sg.id
  type              = "ingress"
  from_port         = 1025
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])
}

resource "aws_security_group_rule" "node_outbound" {
  security_group_id = aws_security_group.data_plane_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Security group for control plane
resource "aws_security_group" "control_plane_sg" {
  name   = "${var.project}-ControlPlane-sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-ControlPlane-sg"
  }
}

# Security group traffic rules
resource "aws_security_group_rule" "control_plane_inbound" {
  security_group_id = aws_security_group.control_plane_sg.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 0), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 1), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])
}

resource "aws_security_group_rule" "control_plane_outbound" {
  security_group_id = aws_security_group.control_plane_sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "mysql_db_sg" {
  name              = "${var.project}-mysql-db-sg"
  description       = "Security group for database"
  vpc_id            = aws_vpc.main.id

  tags = {
    Name            = "${var.project}-mysql-db-sg"
  }
}

resource "aws_security_group_rule" "mysql_db_inbound" {

  security_group_id   = aws_security_group.mysql_db_sg.id
  type                = "ingress"
  from_port           = 3306
  to_port             = 3306
  protocol            = "tcp"
  cidr_blocks         = flatten([cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 2), cidrsubnet(var.vpc_cidr, var.subnet_cidr_bits, 3)])  
}

#--------------------------------EKS Cluster-------------------------------------
resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.project}-cluster"
  role_arn = aws_iam_role.cluster.arn
  version  = "1.24"

  vpc_config {
    subnet_ids              = flatten([aws_subnet.public[*].id, aws_subnet.private[*].id])
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  ]
}

# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name = "${var.project}-Cluster-Role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}


# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.project}-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-cluster-sg"
  }
}

resource "aws_security_group_rule" "cluster_inbound" {
  description              = "Allow worker nodes to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_outbound" {
  description              = "Allow cluster API Server to communicate with the worker nodes"
  from_port                = 1024
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 65535
  type                     = "egress"
}

#------------------------------ EKS Node Groups-----------------------------------------------
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = var.project
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  ami_type       = "AL2_x86_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
  capacity_type  = "ON_DEMAND"  # ON_DEMAND, SPOT
  disk_size      = 20
  instance_types = ["t2.medium"]

  tags = merge(
    var.tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}


# EKS Node IAM Role
resource "aws_iam_role" "node" {
  name = "${var.project}-Worker-Role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}


# EKS Node Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project}-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-node-sg"
  }
}

resource "aws_security_group_rule" "nodes_internal" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "nodes_cluster_inbound" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  to_port                  = 65535
  type                     = "ingress"
}

#---------------------------------------RDS Instance------------------------------

resource "aws_db_instance" "mysql_db" {
  allocated_storage         = var.db_settings.database.allocated_storage
  engine                    = var.db_settings.database.engine
  engine_version            = var.db_settings.database.engine_version
  instance_class            = var.db_settings.database.instance_class
  db_name                   = var.db_settings.database.db_name
  username                  = var.db_username
  password                  = var.db_password
  db_subnet_group_name      = aws_db_subnet_group.mysql_db_subnet_group.id
  vpc_security_group_ids    = [aws_security_group.mysql_db_sg.id]
  skip_final_snapshot       = var.db_settings.database.skip_final_snapshot
}