# Read the ALB back so its DNS name can be handed to the CloudFront origin. The
# controller creates the ALB out-of-band once the Ingresses exist, so wait out the
# provisioning gap, then look it up by the tag stamped on every LB in the group.
# The A records themselves live in cdn/ (they alias CloudFront, not the ALB).

resource "time_sleep" "wait_for_alb" {
  create_duration = "240s"
  depends_on      = [kubernetes_ingress_v1.ecfront, kubernetes_ingress_v1.dashboard]
}

data "aws_lb" "ingress" {
  tags = {
    "ingress.k8s.aws/stack" = "mockten"
  }
  depends_on = [time_sleep.wait_for_alb]
}
