mirrors:
  "rancher":
    endpoint:
      - "http://${registry_url}:5000"
configs:
  "${registry_url}:5000":
    tls:
      ca_file: "/etc/ssl/certs/domain.crt"
