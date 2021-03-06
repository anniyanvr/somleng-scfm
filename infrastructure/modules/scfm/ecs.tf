data "template_file" "appserver_container_definitions" {
  template = file("${path.module}/templates/appserver_container_definitions.json.tpl")

  vars = {
    name = var.app_identifier
    app_port = var.app_port
    app_image      = var.app_image
    nginx_image      = var.nginx_image
    webserver_container_name = var.webserver_container_name
    webserver_container_port = var.webserver_container_port
    region = var.aws_region
    rails_master_key_arn = aws_ssm_parameter.rails_master_key.arn
    aws_sqs_default_queue_name = aws_sqs_queue.this.name
    aws_sqs_scheduler_queue_name = aws_sqs_queue.scheduler.name
    memory = var.memory
    nginx_logs_group = aws_cloudwatch_log_group.nginx.name
    app_logs_group = aws_cloudwatch_log_group.app.name
    logs_group_region = var.aws_region
    app_environment = var.app_environment
    rails_master_key_parameter_arn = aws_ssm_parameter.rails_master_key.arn
    database_password_parameter_arn = aws_ssm_parameter.db_master_password.arn
    database_name = module.db.this_rds_cluster_database_name
    database_username = module.db.this_rds_cluster_master_username
    database_host = module.db.this_rds_cluster_endpoint
    database_port = module.db.this_rds_cluster_port
    db_pool = var.db_pool
    uploads_bucket = aws_s3_bucket.uploads.id
    audio_bucket = aws_s3_bucket.audio.id
  }
}

resource "aws_ecs_task_definition" "appserver" {
  family                   = "${var.app_identifier}-appserver"
  network_mode             = var.network_mode
  requires_compatibilities = [var.launch_type]
  container_definitions = data.template_file.appserver_container_definitions.rendered
  task_role_arn = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.task_execution_role.arn
  cpu = var.cpu
  memory = var.memory
}

resource "local_file" "appserver_task_definition" {
  filename = "${path.module}/../../../deploy/${var.app_environment}/appserver_task_definition.json"
  file_permission = "644"
  content = <<EOF
{
  "family": "${aws_ecs_task_definition.appserver.family}",
  "networkMode": "${aws_ecs_task_definition.appserver.network_mode}",
  "cpu": "${aws_ecs_task_definition.appserver.cpu}",
  "memory": "${aws_ecs_task_definition.appserver.memory}",
  "executionRoleArn": "${aws_ecs_task_definition.appserver.execution_role_arn}",
  "taskRoleArn": "${aws_ecs_task_definition.appserver.task_role_arn}",
  "requiresCompatibilities": ["${var.launch_type}"],
  "containerDefinitions": ${aws_ecs_task_definition.appserver.container_definitions}
}
EOF
}

resource "aws_ecs_service" "appserver" {
  name            = "${var.app_identifier}-appserver"
  cluster         = var.ecs_cluster.id
  task_definition = aws_ecs_task_definition.appserver.arn
  desired_count   = var.ecs_appserver_autoscale_min_instances
  launch_type = var.launch_type
  deployment_controller {
    type = "CODE_DEPLOY"
  }
  network_configuration {
    subnets = var.container_instance_subnets
    security_groups = [aws_security_group.appserver.id, aws_security_group.db.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this[0].arn
    container_name   = var.webserver_container_name
    container_port   = var.webserver_container_port
  }

  lifecycle {
    ignore_changes = [load_balancer, task_definition]
  }
}

data "template_file" "worker_container_definitions" {
  template = file("${path.module}/templates/worker_container_definitions.json.tpl")

  vars = {
    name = var.app_identifier
    app_image      = var.app_image
    rails_master_key_arn = aws_ssm_parameter.rails_master_key.arn
    region = var.aws_region
    aws_sqs_default_queue_name = aws_sqs_queue.this.name
    aws_sqs_scheduler_queue_name = aws_sqs_queue.scheduler.name
    memory = var.memory
    worker_logs_group = aws_cloudwatch_log_group.worker.name
    logs_group_region = var.aws_region
    app_environment = var.app_environment
    rails_master_key_parameter_arn = aws_ssm_parameter.rails_master_key.arn
    database_password_parameter_arn = aws_ssm_parameter.db_master_password.arn
    database_name = module.db.this_rds_cluster_database_name
    database_username = module.db.this_rds_cluster_master_username
    database_host = module.db.this_rds_cluster_endpoint
    database_port = module.db.this_rds_cluster_port
    db_pool = var.db_pool
    uploads_bucket = aws_s3_bucket.uploads.id
    audio_bucket = aws_s3_bucket.audio.id
  }
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.app_identifier}-worker"
  network_mode             = var.network_mode
  requires_compatibilities = [var.launch_type]
  container_definitions = data.template_file.worker_container_definitions.rendered
  task_role_arn = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.task_execution_role.arn
  cpu = var.cpu
  memory = var.memory
}

resource "local_file" "worker_task_definition" {
  filename = "${path.module}/../../../deploy/${var.app_environment}/worker_task_definition.json"
  file_permission = "644"
  content = <<EOF
{
  "family": "${aws_ecs_task_definition.worker.family}",
  "networkMode": "${aws_ecs_task_definition.worker.network_mode}",
  "cpu": "${aws_ecs_task_definition.worker.cpu}",
  "memory": "${aws_ecs_task_definition.worker.memory}",
  "executionRoleArn": "${aws_ecs_task_definition.worker.execution_role_arn}",
  "taskRoleArn": "${aws_ecs_task_definition.worker.task_role_arn}",
  "requiresCompatibilities": ["${var.launch_type}"],
  "containerDefinitions": ${aws_ecs_task_definition.worker.container_definitions}
}
EOF
}

resource "aws_ecs_service" "worker" {
  name            = "${var.app_identifier}-worker"
  cluster         = var.ecs_cluster.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.ecs_worker_autoscale_min_instances
  launch_type = var.launch_type

  network_configuration {
    subnets = var.container_instance_subnets
    security_groups = [aws_security_group.worker.id, aws_security_group.db.id]
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}
