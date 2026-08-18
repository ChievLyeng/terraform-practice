output "server_name" {
  description = "The randomly generated name Terraform created"
  value       = random_pet.server_name.id
}

output "config_file_path" {
  value = local_file.server_config.filename
}
