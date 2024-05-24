# ALB
resource "aws_lb" "main" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = [module.network.public_subnet_1_id, module.network.public_subnet_2_id]
}

# Listener Rules
resource "aws_lb_listener_rule" "http_redirect" {
  listener_arn = aws_lb.main.arn
  action {
    type             = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  condition {
    host_header {
        values = ["*"]
    }
  }
}

/*resource "aws_lb_listener_rule" "https_to_ecs" {
  listener_arn = aws_lb.main.arn
  action {
    type             = "forward"
    target_group_arn = module.load_balancer.target_group_arn
  }
  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}*/
