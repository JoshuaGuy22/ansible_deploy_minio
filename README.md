
# MinIO Ansible Role

This Ansible role automates the deployment of MinIO in a Multi-Node Multi-Drive (MNMD) configuration. It handles the installation of MinIO, configuration of systemd services, creation of storage directories, and ensures secure permissions on environment files. The role also allows flexibility for deploying different clusters by setting up variables in `group_vars`.

## Role Structure

```
Prerequisites:
inventory.ini
group_vars/
└── minio_cluster_1.yaml
roles/
└── deply_minio.yaml

Role:
roles/minio/
├── defaults/
│   └── main.yaml
├── files/
│   └── CREATE_XFS.SH !!! RUN WITH EXTREME CAUTION - THIS WILL FORMAT YOUR DRIVES !!!
├── handlers/
│   └── main.yaml
├── tasks/
│   └── main.yaml
├── templates/
│   ├── minio.env.j2
│   └── minio.service.j2
└── README.md
```

## Requirements

- This role is designed for Ubuntu-based systems - specifically Ubuntu 24.04 LTS.
- Ensure the servers have internet access to download MinIO packages.
- All nodes must have connectivity between each other on the network.
  - The Ansible role will take care of hosts, although you may need to run it locally on one first, then the rest.
  - Ensure all nodes can SSH w/o password to eachother
  - Ensure all nodes can SSH w/o password to themselves (E.g. localhost)
- Each node needs to have formatted XFS drives with the appropriate labels 
  - Run CREATE_XFS.sh before beginning MinIO installation and verify all drives are formatted with XFS and mounted
  - This will automatically detect sd devices for use in MinIO
    - My env had /dev/sd* devices for MinIO, the OS was on nvme. So I wanted to pull in all /dev/sd* devices for MinIO
  - Please carfeully review the script and make sure it works for your env.
  - !!!! THIS WILL FORMAT ALL /dev/sd* devices as the script currently stands !!!!


## Role Variables

The role relies on variables defined in `group_vars`, allowing different configurations for different clusters. Here are the key variables:

```yaml
ansible_user: root

### MinIO WEB GUI ###
alias_name_web: minio
web_domain: minio.my.domain.com
web_url: "{{ 'https' if use_tls else 'http' }}://{{ web_domain }}"

### MinIO API ###
alias_name_api: minio-api
api_domain: minio-api.my.domain.com
api_url: "{{ 'https' if use_tls else 'http' }}://{{ api_domain }}"

### TLS ### 
use_tls: true  # Set to false if you don't want to use TLS

### MinIO Configs ###
licence_path: /path/to/minio.license # all servers must access this path
minio_volumes: "{{ 'https' if use_tls else 'http' }}://minio-server-{1...X}:9000/mnt/disk{1...Y}/minio" #assuming each server is named minio-server-{1..X} - Replace X and Y
minio_disk_count: 45 #how many disks are in each minio server
minio_root_user: "MINIO-ADMIN"
# minio_root_password: "MINIO-PASSWORD" #This can be set via included role vars, or here
minio_user: "minio-user"
minio_group: "minio-group"
minio_hosts: # Be sure to have IP/Name format as this will be used to generate /etc/hosts
  - "192.168.1.2 minio-server-1"
  - "192.168.1.3 minio-server-1"
  - "192.168.1.4 minio-server-1"
  - "192.168.1.5 minio-server-1"
```

- `minio_user`: The user running the MinIO process.
- `minio_group`: The group associated with the MinIO user.
- `minio_volumes`: The disk and node configuration for MinIO.
- `minio_disk_count`: The number of disks (can vary depending on the cluster).
- `minio_root_user`: The root user for MinIO.
- `minio_root_password`: The root password for MinIO.
- `minio_console_address`: The port for the MinIO console.

## Usage
1. **Define Inventory and Group Vars**

   Set up your inventory (`inventory.ini`) to define your MinIO cluster hosts:

   **inventory**:
   ```ini
   [minio_cluster_1]
   minio-server-1 ansible_host=192.168.1.2
   minio-server-2 ansible_host=192.168.1.3
   minio-server-3 ansible_host=192.168.1.4
   minio-server-4 ansible_host=192.168.1.5
   ```
   
2. **Define `group_vars/minio_cluster_1.yaml` with MinIO-specific settings**:

   *Example: group_vars/minio-cluster-1.yml*:
      ```yaml
      minio_volumes: "http://minio-server-{1...4}:9000/mnt/disk{1..45}/minio"
      minio_disk_count: 45
      minio_root_user: "ADMIN"
      minio_root_password: "ADMIN"
      ... etc
      ```

3. **Run the Playbook on First Node**

   Run the Ansible playbook to deploy MinIO across first node:

   ```bash
   ansible-playbook -i inventory -l $(hostname) roles/deploy_minio.yaml
   ```

4. **Run the Playbook Accross the Cluster**

   Run the Ansible playbook to deploy MinIO across all nodes:

   ```bash
   ansible-playbook -i inventory -l minio_cluster_1 roles/deploy_minio.yaml ### Change to appropriate group 
   ```

5. **Verify MinIO is running**
   ```
   systemctl status minio
   ```
   The role will deploy MinIO, configure systemd, and create necessary directories and permissions, as well as set up /etc/hosts.



   ## Ingress/SSL using Kubernetes
   - I use NGINX Ingress/Services along side Kubernetes/LetsEncrypt to route all traffic to minio.my.domain.com to the minio-server{1..X} IPs.
   - The Ansible Role will generate self-signed certificates if `use_tls` is set to true. However, I also use Kubernetes Ingress/Services for the full domain name routing/SSL certificates.
   - There may be other ways you can set up your ingress and certificates. You may need to adjust this role to fit your method.
   - If you also use Kubernetes/LetsEncrypt, I will provide the `yaml` below as an example:
  
     ```
      apiVersion: v1
      kind: Service
      metadata:
        name: minio-cluster
        labels:
          app: minio-cluster
      spec:
        ports:
          - protocol: TCP
            name: http
            port: 443
            targetPort: 9001
      ---
      apiVersion: v1
      kind: Endpoints
      metadata:
        name: minio-cluster
      subsets:
        - addresses:
            - ip: 192.168.1.2
              hostname: minio-server-1
            - ip: 192.168.1.3
              hostname: minio-server-2
            - ip: 192.168.1.4
              hostname: minio-server-3
            - ip: 192.168.1.5
              hostname: minio-server-4
          ports:
            - port: 9001
              name: http
      ---
      apiVersion: "networking.k8s.io/v1"
      kind: Ingress
      metadata:
        name: minio-cluster
        labels:
          app: minio-cluster
        annotations:
          kubernetes.io/ingress.class: "nginx"
          cert-manager.io/cluster-issuer: "letsencrypt"
          nginx.ingress.kubernetes.io/proxy-body-size: 160m
          nginx.ingress.kubernetes.io/client-body-size: "160m"
          nginx.ingress.kubernetes.io/proxy-connect-timeout: 60s
          nginx.ingress.kubernetes.io/proxy-read-timeout: 1800s
          nginx.ingress.kubernetes.io/proxy-send-timeout: 1800s
          nginx.org/client-max-body-size: 160m
          nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
          nginx.ingress.kubernetes.io/ssl-redirect: "true"
          nginx.ingress.kubernetes.io/configuration-snippet: |
            more_set_headers "X-Forwarded-Proto: https";
            more_set_headers "X-Forwarded-Ssl: on";
          nginx.ingress.kubernetes.io/websocket-services: "minio-cluster"
          nginx.ingress.kubernetes.io/backend-protocol: "HTTPS" #remove if not using HTTPS
          nginx.ingress.kubernetes.io/secure-backends: "true" #remove if not using HTTPS 
      
      spec:
        tls:
          - hosts:
              - minio.my.domain.com
            secretName: minio-cluster-tls
        rules:
          - host: minio.my.domain.com
            http:
              paths:
                - path: /
                  pathType: ImplementationSpecific
                  backend:
                    service:
                      name: minio-cluster
                      port:
                        number: 443
      
      ---
      
      apiVersion: v1
      kind: Service
      metadata:
        name: minio-cluster-api
        labels:
          app: minio-cluster-api
      spec:
        ports:
          - protocol: TCP
            name: http
            port: 443
            targetPort: 9000
      ---
      apiVersion: v1
      kind: Endpoints
      metadata:
        name: minio-cluster-api
      subsets:
        - addresses:
            - ip: 192.168.1.2
              hostname: minio-server-1
            - ip: 192.168.1.3
              hostname: minio-server-2
            - ip: 192.168.1.4
              hostname: minio-server-3
            - ip: 192.168.1.5
              hostname: minio-server-4
          ports:
            - port: 9000
              name: http
      ---
      apiVersion: "networking.k8s.io/v1"
      kind: Ingress
      metadata:
        name: minio-cluster-api
        labels:
          app: minio-cluster-api
        annotations:
          kubernetes.io/ingress.class: "nginx"
          cert-manager.io/cluster-issuer: "letsencrypt"
          nginx.ingress.kubernetes.io/proxy-body-size: 160m
          nginx.ingress.kubernetes.io/client-body-size: "160m"
          nginx.ingress.kubernetes.io/proxy-connect-timeout: 60s
          nginx.ingress.kubernetes.io/proxy-read-timeout: 1800s
          nginx.ingress.kubernetes.io/proxy-send-timeout: 1800s
          nginx.org/client-max-body-size: 160m
          nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
          nginx.ingress.kubernetes.io/ssl-redirect: "true"
          nginx.ingress.kubernetes.io/configuration-snippet: |
            more_set_headers "X-Forwarded-Proto: https";
            more_set_headers "X-Forwarded-Ssl: on";
          nginx.ingress.kubernetes.io/websocket-services: "minio-cluster-api"
          nginx.ingress.kubernetes.io/backend-protocol: "HTTPS" #remove if not using HTTPS
          nginx.ingress.kubernetes.io/secure-backends: "true" #remove if not using HTTPS 
      spec:
        tls:
          - hosts:
              - minio-api.my.domain.com
            secretName: minio-cluster-api-tls
        rules:
          - host: minio-api.my.domain.com
            http:
              paths:
                - path: /
                  pathType: ImplementationSpecific
                  backend:
                    service:
                      name: minio-cluster-api
                      port:
                        number: 443
     ```
