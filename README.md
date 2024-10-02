
# MinIO (HOSS) Ansible Role

This Ansible role automates the deployment of MinIO in a Multi-Node Multi-Drive (MNMD) configuration. It handles the installation of MinIO, configuration of systemd services, creation of storage directories, and ensures secure permissions on environment files. The role also allows flexibility for deploying different clusters by setting up variables in `group_vars`.

## Role Structure

```
Group Vars:
/repo/bright-ansible/group_vars/

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
minio_hosts:
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

   *Example: group_vars/hoss_hq.yml*:
      ```yaml
      minio_volumes: "http://minio-server-{1...4}:9000/mnt/disk{1..45}/minio"
      minio_disk_count: 45
      minio_root_user: "ADMIN"
      minio_root_password: "ADMIN"
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
