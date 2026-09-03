
**Troubleshooting**

**Error:** lookup registry on 127.0.0.53:53

**Resolution:** Add {"insecure-registries": ["localhost:5000", "172.17.0.1:5000"]} to /etc/docker/daemon.json 
