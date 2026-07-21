variable "secret_name" {
  description = "The name of the Kubernetes secret for image pull"
  type        = string
}

variable "google_client_id" {
  description = "Google OAuth client ID"
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "facebook_client_id" {
  description = "Facebook OAuth client ID"
  type        = string
  default     = ""
}

variable "facebook_client_secret" {
  description = "Facebook OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "kc_hostname" {
  description = "Keycloak KC_HOSTNAME. localhost on docker-desktop; the public domain (e.g. example.dpdns.org) behind real HTTPS."
  type        = string
  default     = "localhost"
}

variable "kc_dev_mode" {
  description = "Keycloak DEV_MODE. true relaxes hostname/proxy strictness for local; set false behind real TLS."
  type        = string
  default     = "true"
}

variable "redirect_uris" {
  description = "Realm client redirect URIs. Every origin a login can land on must be here or Keycloak rejects the callback."
  type        = list(string)
  default     = ["http://localhost/*", "http://nginx/*"]
}

variable "web_origins" {
  description = "Realm client web origins (CORS)."
  type        = list(string)
  default     = ["http://localhost", "http://nginx"]
}

variable "mockten_mode" {
  description = "dev or cloud. cloud makes the image import realm-export-cloud.json, which derives its origins from PUBLIC_BASE_DOMAIN and enables direct access grants."
  type        = string
  default     = "dev"
}

variable "public_base_domain" {
  description = "Bare public domain the cloud realm's origins are generated from. Required when mockten_mode is cloud."
  type        = string
  default     = ""
}

variable "realm_name" {
  description = "Realm the app uses. Also appears in the ingress paths and in the OAuth providers' registered redirect URIs, so renaming it means re-registering with Google and Facebook."
  type        = string
  default     = "mockten-realm-dev"
}

# ── E2E admin account (cloud only) ───────────────────────────────────────────
variable "e2e_admin_enabled" {
  description = "Create a dedicated admin account for the E2E suite. Plan-time constant."
  type        = bool
  default     = false
}

variable "e2e_admin_user" {
  description = "Username/email of the E2E admin. Deliberately not a personal address."
  type        = string
  default     = ""
}

variable "e2e_admin_password" {
  description = "Password for the E2E admin. Generated, never written to the repo."
  type        = string
  sensitive   = true
  default     = ""
}

# Defaults match the values baked into the uam image. They are not reachable
# from outside (the ingress does not route /admin/, and it is IP-allowlisted),
# but they are defaults in an internet-facing image, so mockten has been asked
# to make them overridable; these variables are where the real values will go.
variable "kc_admin_user" {
  description = "Keycloak master-realm admin username, used only in-cluster by the E2E bootstrap Job."
  type        = string
  default     = "admin"
}

variable "kc_admin_password" {
  description = "Keycloak master-realm admin password, used only in-cluster by the E2E bootstrap Job."
  type        = string
  sensitive   = true
  default     = "admin"
}
