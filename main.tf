terraform {
  backend "s3" {
    region  = "us-east-1"
    key     = "terrraform.tfstate"
    encrypt = "true"
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  required_version = ">= 0.13"
}
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Environment = "demo"
      ManagedBy   = "terraform"
    }
  }
}

resource "aws_ecs_cluster" "hello_world_cluster" {
  name = "hello-world-cluster"
}

resource "aws_cloudwatch_log_group" "hello_world_log_group" {
  name              = "/ecs/hello-world"
  retention_in_days = 7
}
resource "aws_ecs_task_definition" "hello_world_task" {
  family                   = "hello-world-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "hello-world"
    image     = "anilyadava/hello-world:latest"
    essential = true
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/hello-world"
        "awslogs-region"        = "us-east-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_ecs_service" "hello_world_service" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.hello_world_cluster.id
  task_definition = aws_ecs_task_definition.hello_world_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.demo.id,aws_subnet.demo1.id]
    security_groups = [aws_security_group.demo.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.hello_world_tg.arn
    container_name   = "hello-world"
    container_port   = 3000
  }
  depends_on = [  
    aws_lb.hello_world_lb,
    aws_lb_listener.hello_world_listener
  ]
}

resource "aws_lb" "hello_world_lb" {
  name               = "hello-world-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.demo.id]
  subnets            = [aws_subnet.demo.id,aws_subnet.demo1.id ]
}

resource "aws_lb_target_group" "hello_world_tg" {
  name     = "hello-world-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo.id
  target_type = "ip"
}

resource "aws_lb_listener" "hello_world_listener" {
  load_balancer_arn = aws_lb.hello_world_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hello_world_tg.arn
  }
}

resource "aws_vpc" "demo" {
  cidr_block = "10.0.0.0/16"
}

#IGW
resource "aws_internet_gateway" "demo-igw" {
  vpc_id = aws_vpc.demo.id
}

resource "aws_subnet" "demo" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}
resource "aws_subnet" "demo1" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

###RT for subnet
resource "aws_route_table" "public_demo_rt" {
  vpc_id = aws_vpc.demo.id
  ###route for igw
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-igw.id
  }
}
resource "aws_route_table_association" "public_association_demo" {
  count = 2
  subnet_id      = element([aws_subnet.demo.id, aws_subnet.demo1.id], count.index)
  route_table_id = aws_route_table.public_demo_rt.id
}

resource "aws_security_group" "demo" {
  vpc_id = aws_vpc.demo.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

