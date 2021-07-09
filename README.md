This will create the following resources -
1. A New VPC with 2 subnets in two availability zones 
2. An ALB infront of an ASG with a target group having two webservers spanning accross two AZs
3. Output - DNS of the ALB.

Note - Terraform back end is not confugured. You can add backend such as Consul or S3 with Dynamo DB if multiple people are working on the same code. This will ensure that the terraform stage file is locked and not overwritten by users if they try to update at the same time.

Also back end DB is not created. Only security group is created.

Also the resources can be created in separate modules for better reusability and maintainability.