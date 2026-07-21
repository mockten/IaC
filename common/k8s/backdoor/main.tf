resource "kubernetes_config_map" "backdoor_script" {
  metadata {
    name      = "backdoor-script"
    namespace = "default"
  }
  data = {
    "server.py" = <<-EOF
import http.server
import json
import mysql.connector
import urllib.request
import urllib.parse

MYSQL_HOST = "mysql-service.default.svc.cluster.local"
MYSQL_USER = "mocktenusr"
MYSQL_PASS = "mocktenpassword"
MYSQL_DB   = "mocktendb"
UAM_HOST   = "uam-service.default.svc.cluster.local"

PRODUCT_ID = "b91a5d68-6acb-48e7-8e5d-3d85b7e76af2"

class Handler(http.server.BaseHTTPRequestHandler):
    def send_json(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def send_html(self, html, status=200):
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode())

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        if self.path == "/api/test/reset-stock":
            try:
                conn = mysql.connector.connect(
                    host=MYSQL_HOST, user=MYSQL_USER,
                    password=MYSQL_PASS, database=MYSQL_DB
                )
                cur = conn.cursor()
                cur.execute("UPDATE Stock SET stocks = 10 WHERE product_id = %s", (PRODUCT_ID,))
                cur.execute("DELETE FROM Wishlist")
                conn.commit()
                cur.close()
                conn.close()
                self.send_json({"ok": True})
            except Exception as e:
                self.send_json({"ok": False, "error": str(e)}, 500)
        else:
            self.send_json({"error": "not found"}, 404)

    def do_GET(self):
        if self.path.startswith("/api/test/auth-backdoor"):
            qs = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(qs)
            username = params.get("username", ["superadmin"])[0]
            password = params.get("password", [username])[0]

            token_url = f"http://{UAM_HOST}/realms/mockten-realm-dev/protocol/openid-connect/token"
            token_data = urllib.parse.urlencode({
                "username": username,
                "password": password,
                "grant_type": "password",
                "client_id": "mockten-react-client"
            }).encode()

            try:
                req = urllib.request.Request(token_url, data=token_data)
                resp = urllib.request.urlopen(req)
                token = json.loads(resp.read())
                access_token = token.get("access_token", "")
                refresh_token = token.get("refresh_token", "")

                html = f"""<!DOCTYPE html>
<html><body>
<script>
localStorage.setItem("access_token", {json.dumps(access_token)});
localStorage.setItem("refresh_token", {json.dumps(refresh_token)});
document.cookie = "access_token={access_token}; path=/";
document.cookie = "refresh_token={refresh_token}; path=/";
window.location.href = "/";
</script>
</body></html>"""
                self.send_html(html)
            except Exception as e:
                self.send_json({"ok": False, "error": str(e)}, 500)
        else:
            self.send_json({"error": "not found"}, 404)

http.server.HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
EOF
  }
}

resource "kubernetes_deployment" "backdoor" {
  metadata {
    name      = "backdoor-deploy"
    namespace = "default"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "backdoor"
      }
    }
    template {
      metadata {
        labels = {
          app = "backdoor"
        }
      }
      spec {
        image_pull_secrets {
          name = var.secret_name
        }
        init_container {
          name    = "install-deps"
          image   = "python:3.11-slim"
          command = ["sh", "-c", "pip install --quiet --target=/app mysql-connector-python && cp /etc/backdoor/server.py /app/"]
          volume_mount {
            name       = "script"
            mount_path = "/etc/backdoor"
          }
          volume_mount {
            name       = "app"
            mount_path = "/app"
          }
        }
        container {
          name    = "backdoor"
          image   = "python:3.11-slim"
          command = ["python", "/app/server.py"]
          env {
            name  = "PYTHONPATH"
            value = "/app"
          }
          port {
            container_port = 8080
          }
          volume_mount {
            name       = "app"
            mount_path = "/app"
          }
        }
        volume {
          name = "script"
          config_map {
            name = kubernetes_config_map.backdoor_script.metadata[0].name
          }
        }
        volume {
          name = "app"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "backdoor" {
  metadata {
    name      = "backdoor-service"
    namespace = "default"
  }
  spec {
    selector = {
      app = "backdoor"
    }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}
