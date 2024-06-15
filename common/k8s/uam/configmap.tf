resource "kubernetes_config_map" "mockten_realm" {
  metadata {
    name      = "mockten-realm-config"
    namespace = "default"
  }

  data = {
    "realm-export.json" = <<EOT
{
  "realm": "mockten-realm-dev",
  "enabled": true,
  "clients": [
    {
      "clientId": "mockten-react-client",
      "enabled": true,
      "secret": "mockten-client-secret",
      "redirectUris": ["http://localhost/*"],
      "publicClient": false,
      "protocol": "openid-connect",
      "directAccessGrantsEnabled": true,
      "attributes": {
        "client_credentials": "true",
        "access.token": "true"
      },
      "defaultClientScopes": ["web-origins", "role_list", "profile"]
    }
  ],
  "clientScopes": [
    {
      "name": "profile",
      "description": "profile scope",
      "protocol": "openid-connect",
      "attributes": {
        "include.in.token.scope": "true",
        "display.on.consent.screen": "true"
      },
      "protocolMappers": [
        {
          "name": "username",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-usermodel-property-mapper",
          "consentRequired": false,
          "config": {
            "userinfo.token.claim": "true",
            "user.attribute": "username",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "claim.name": "preferred_username",
            "jsonType.label": "String"
          }
        },
        {
          "name": "roles",
          "protocol": "openid-connect",
          "protocolMapper": "oidc-usermodel-realm-role-mapper",
          "consentRequired": false,
          "config": {
            "multivalued": "true",
            "userinfo.token.claim": "true",
            "id.token.claim": "true",
            "access.token.claim": "true",
            "claim.name": "roles",
            "jsonType.label": "String"
          }
        }
      ]
    }
  ],
  "roles": {
    "realm": [
      {
        "name": "seller",
        "description": "Role for sellers"
      }
    ]
  },
  "groups": [
    {
      "name": "Seller"
    }
  ],
  "users": [
    {
      "username": "superadmin",
      "enabled": true,
      "emailVerified": true,
      "email": "superadmin@example.com",
      "firstName": "Super",
      "lastName": "Admin",
      "credentials": [
        {
          "type": "password",
          "value": "superadmin"
        }
      ]
    },
    {
      "username": "seller",
      "enabled": true,
      "emailVerified": true,
      "email": "seller@example.com",
      "firstName": "Seller",
      "lastName": "B",
      "credentials": [
        {
          "type": "password",
          "value": "seller"
        }
      ],
      "groups": [
        "Seller"
      ],
      "realmRoles": [
        "seller"
      ]
    }
  ]
}
EOT
  }
}
