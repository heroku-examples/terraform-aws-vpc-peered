[
  {
    "name": "health-checker-app",
    "image": "${app_image}",
    "cpu": 0,
    "environment": [
      { "name" : "PORT", "value" : "${app_port}" }
    ],
    "essential": true,
    "memoryReservation": 256,
    "mountPoints": [],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${logs_group}",
          "awslogs-region": "${aws_region}",
          "awslogs-stream-prefix": "ecs"
        }
    },
    "portMappings": [
      {
        "containerPort": ${app_port},
        "hostPort": ${app_port},
        "protocol": "tcp"
      }
    ],
    "volumesFrom": []
  }
]