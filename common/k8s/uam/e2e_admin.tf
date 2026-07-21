# A dedicated admin account for the cloud E2E suite.
#
# Why a Job and not the Terraform keycloak provider: that provider needs HTTP
# reach to Keycloak's Admin API, and nothing outside the cluster has it. The
# ingress routes only /realms/*/broker/ and /realms/*/login-actions/ to uam, and
# the GitHub Actions runner is allowlisted on the CONTROL PLANE only, never on
# the data-plane ingress. So a laptop apply might work through a port-forward,
# but CI could never reach it — and a step that only works by hand is exactly
# what this repo forbids. A Job runs inside the cluster and talks to
# uam-service directly, so laptop and CI behave identically.
#
# The realm is owned by the uam image, so the account cannot be declared there
# without baking a test credential into every environment.

resource "kubernetes_secret" "e2e_admin" {
  count = var.e2e_admin_enabled ? 1 : 0
  metadata {
    name      = "e2e-admin"
    namespace = "default"
  }
  data = {
    username = var.e2e_admin_user
    password = var.e2e_admin_password
  }
}

resource "kubernetes_job" "e2e_admin" {
  count = var.e2e_admin_enabled ? 1 : 0

  metadata {
    name      = "e2e-admin-bootstrap"
    namespace = "default"
  }

  spec {
    backoff_limit = 6

    # Let Kubernetes delete the finished pod. Without this it lingers as
    # "Exited/Succeeded" forever and the dashboard permanently reads
    # "Stopped / Exited: 1" — which teaches the operator that 1 is normal and
    # quietly costs them the ability to notice when it becomes 2. Five minutes
    # is long enough to read the logs if the bootstrap needs debugging.
    ttl_seconds_after_finished = 300

    template {
      metadata {
        labels = { app = "e2e-admin-bootstrap" }
      }
      spec {
        restart_policy = "OnFailure"
        container {
          name  = "bootstrap"
          image = "alpine:3.20"

          env {
            name  = "KC"
            value = "http://uam-service.default.svc.cluster.local"
          }
          env {
            name  = "REALM"
            value = var.realm_name
          }
          env {
            name  = "KC_ADMIN"
            value = var.kc_admin_user
          }
          env {
            name  = "KC_ADMIN_PASSWORD"
            value = var.kc_admin_password
          }
          env {
            name = "E2E_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.e2e_admin[0].metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "E2E_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.e2e_admin[0].metadata[0].name
                key  = "password"
              }
            }
          }

          command = ["/bin/sh", "-c"]
          # Idempotent throughout: the Job may be retried by backoffLimit, and a
          # re-apply must not fail because the user already exists.
          args = [<<-EOT
            set -eu
            apk add --no-cache curl jq >/dev/null

            echo "waiting for keycloak..."
            for i in $(seq 1 90); do
              curl -sf "$KC/realms/$REALM/.well-known/openid-configuration" >/dev/null 2>&1 && break
              sleep 5
            done
            curl -sf "$KC/realms/$REALM/.well-known/openid-configuration" >/dev/null

            TOKEN=$(curl -s --fail-with-body \
              -d "client_id=admin-cli" -d "grant_type=password" \
              --data-urlencode "username=$KC_ADMIN" \
              --data-urlencode "password=$KC_ADMIN_PASSWORD" \
              "$KC/realms/master/protocol/openid-connect/token" | jq -er .access_token)
            AUTH="Authorization: Bearer $TOKEN"

            UID_=$(curl -s -H "$AUTH" \
              --get --data-urlencode "username=$E2E_USER" --data-urlencode "exact=true" \
              "$KC/admin/realms/$REALM/users" | jq -r '.[0].id // empty')

            if [ -z "$UID_" ]; then
              echo "creating $E2E_USER"
              curl -s --fail-with-body -X POST -H "$AUTH" -H "Content-Type: application/json" \
                -d "$(jq -n --arg u "$E2E_USER" \
                     '{username:$u,email:$u,emailVerified:true,enabled:true,firstName:"E2E",lastName:"Admin"}')" \
                "$KC/admin/realms/$REALM/users"
              UID_=$(curl -s -H "$AUTH" \
                --get --data-urlencode "username=$E2E_USER" --data-urlencode "exact=true" \
                "$KC/admin/realms/$REALM/users" | jq -er '.[0].id')
            else
              echo "$E2E_USER already exists ($UID_)"
            fi

            echo "setting password"
            curl -s --fail-with-body -X PUT -H "$AUTH" -H "Content-Type: application/json" \
              -d "$(jq -n --arg p "$E2E_PASSWORD" '{type:"password",value:$p,temporary:false}')" \
              "$KC/admin/realms/$REALM/users/$UID_/reset-password"

            # The dashboard authorises on group membership, not on a realm role.
            GID=$(curl -s -H "$AUTH" "$KC/admin/realms/$REALM/groups" \
              | jq -er '.. | objects | select(.name=="admin-group") | .id' | head -1)
            echo "joining admin-group ($GID)"
            curl -s --fail-with-body -X PUT -H "$AUTH" \
              "$KC/admin/realms/$REALM/users/$UID_/groups/$GID"

            echo "E2E_ADMIN_BOOTSTRAP_OK"
          EOT
          ]
        }
      }
    }
  }

  # The Job polls for Keycloak anyway, but without this Terraform may create it
  # before the Deployment exists at all.
  depends_on = [kubernetes_deployment.uam]

  wait_for_completion = true
  timeouts {
    create = "10m"
  }
}
