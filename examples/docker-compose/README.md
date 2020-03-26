In this example, we use the module to generate a Quorum Network which runs in Docker with Docker Compose support. 

## Getting Started

```
terraform apply --auto-approve
docker-compose -f build/my-network/docker-compose.yml up -d
```

`ethstats` is also available at http://localhost:3000