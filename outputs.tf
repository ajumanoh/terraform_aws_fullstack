##############################################################################################
# OUTPUT                                                                                     #
##############################################################################################
output "alb_url" {
 description = "ALB URL"
 value = aws_lb.web_alb.dns_name 
}