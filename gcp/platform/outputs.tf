# Cloud-native ingress has no in-cluster controller Service to hairpin to (that was
# the nginx model). The dashboard's readiness self-check reaches the external LB
# directly; the cluster's Cloud NAT egress IP is allowlisted in Cloud Armor so that
# probe is not blocked. Hence no ingress_cluster_ip output here.
