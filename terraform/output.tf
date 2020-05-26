output controllers {
  value = [ for id in module.k8s_controllers.id : format("aws ssm start-session --target %s", id) ]
}

output workers {
  value = [ for id in module.k8s_workers.id : format("aws ssm start-session --target %s", id) ]
}

resource "local_file" "private_key" {
  sensitive_content     = tls_private_key.this.private_key_pem
  filename = "${path.module}/${aws_key_pair.this.key_name}.pem"
  file_permission = "600"
}
