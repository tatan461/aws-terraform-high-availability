output "website_url" {
  value       = "http://${module.alb.alb_dns_name}"
  description = "The public URL to test your high-availability application"
}
