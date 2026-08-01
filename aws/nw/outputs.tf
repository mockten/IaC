output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }

# The cluster's single egress IP. In-cluster pods (e.g. the dashboard's readiness
# check) reach the internet-facing ALB through this, so it is allowed on the ALB
# alongside the operator's allowlist.
output "nat_public_ip" { value = aws_eip.nat.public_ip }
