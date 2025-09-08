# Artemis — DevOps & Security Additions

> **Note:** The source code for this project is taken from the existing [ls1intum/Artemis](https://github.com/ls1intum/Artemis) codebase. The following DevOps and security topics have been added on top of the original codebase as part of a TUM (Technical University of Munich) project.

## Added DevOps & Security Topics

### Container Build & Image Security
- **Minimized Images with Multistage Builds**: Artemis Dockerfile uses multi-stage build — Eclipse Temurin JDK builder stage followed by minimal runtime stage, with non-root user (`artemis`, UID 1337)
- **Restrictions for Containers (Build Time)**: Kaniko used for rootless, daemonless container builds in CI — no Docker daemon required, reducing attack surface during build
- **Restrictions for Containers (Run Time)**: All deployments (Artemis, Kafka, Zookeeper, Gateway, MySQL, JHipster Registry) enforce `securityContext` with `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, and `runAsNonRoot: true`
- **Use Hadolint to Check Images**: Hadolint lints the Artemis Dockerfile in CI for best practices and misconfigurations
- **Tools to Scan for Vulnerabilities in Containers**: Trivy scans Dockerfiles for misconfigurations (pre-build) and built images for vulnerabilities (post-build, fails on CRITICAL); Trivy Operator runs continuous in-cluster scanning with CIS, NSA, and PSS compliance reports

### CI/CD Pipeline
- **CI/CD Pipeline**: GitLab CI with 3 stages — pre-build (Hadolint, Conftest/OPA, Trivy Dockerfile scan), build (Kaniko, Cosign), post-build (Trivy image scan, Kustomize manifest updates)

### Image Signing & Admission Control
- **Signatures Management on Containerized Environments**: Cosign (v2.5.3) signs the built image with a private key; Connaisseur enforces signature validation at admission time (NotaryV1 + Cosign validators) with default-deny policy
- **Admission Controllers**: Connaisseur for image signature verification; OPA Gatekeeper for policy enforcement (blocks privileged containers and unapproved image registries)
- **Policy Enforcement**: OPA Gatekeeper ConstraintTemplates for image registry whitelist and no-privileged-container policies; OPA/Rego policies for Dockerfile linting via Conftest (no unused build stages)

### Kubernetes Security
- **Kubernetes Deployment**: Full K8s manifests (Deployments, StatefulSets, Services, ConfigMaps, PVCs, Ingress) with Kustomize
- **K8s Security Context and Secrets**: All pods run with `runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, `readOnlyRootFilesystem: true` (where supported); secrets injected from External Secrets (not hardcoded)
- **Pod Security Standards**: Enforced via Gatekeeper constraints (no-privileged-container policy)

### Network Security
- **Kubernetes Network Policies**: 8 CiliumNetworkPolicy files for microsegmentation — per-service policies for DNS, MySQL, Kafka, Zookeeper, JHipster Registry, Gateway, and Artemis app
- **Cilium CNI & Hubble**: eBPF-based networking with per-service network policies and observability via Hubble (traffic monitoring, flow filtering by namespace/port)

### Secrets & Infrastructure
- **Secret Management**: External Secrets Operator (ESO) syncs secrets from Google Cloud Secret Manager to Kubernetes; Reflector enables cross-namespace secret sync; Reloader auto-restarts pods on secret changes
- **Terraform IaC**: 4-stage Terraform modules (Cilium, Google Secrets Manager, External Secrets, Helm packages for Connaisseur/Trivy/Falco/Gatekeeper)

### Runtime Security & Compliance
- **Introducing Anomaly Detection Tooling like Falco**: Falco deployed with eBPF driver and containerd socket integration for runtime threat detection
- **Container Image Scanning & Compliance**: Trivy Operator generates vulnerability, SBOM, config audit, RBAC assessment, infra assessment, and cluster compliance reports (CIS 1.23, NSA 1.0, PSS baseline/restricted)

---

## Prerequisites
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- [gke-gcloud-auth-plugin](https://cloud.google.com/blog/products/containers-kubernetes/kubectl-auth-changes-in-gke)
   ```sh
   sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
   ```
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [kubectx](https://github.com/ahmetb/kubectx?tab=readme-ov-file#installation)

## Connecting to Google Kubernetes Engine

> **Note:** The gcloud commands below are specific to our project setup. Adjust the project ID, zone, and cluster name to match your own GKE deployment.

Artemis Kubernetes cluster has been setup on Google Kubernetes Engine. To connect and view resources, run:

```sh
gcloud container clusters get-credentials <YOUR_CLUSTER_NAME> \
   --zone <YOUR_ZONE> \
   --project <YOUR_PROJECT_ID>

kubectx gke_<YOUR_PROJECT_ID>_<YOUR_ZONE>_<YOUR_CLUSTER_NAME>
```

Note: IAM permissions are required to connect to the cluster.

## Setup Steps

1. **Authenticate with Google Cloud:**
   ```sh
   gcloud auth application-default login
   gcloud config set project <YOUR_PROJECT_ID>
   ```

2. **Deploy Cilium Module with Terraform:**
   ```sh
   cd infra/terraform/0_cilium
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy Google Secrets Manager Module:**
   ```sh
   cd infra/terraform/1_google-secrets-manager
   terraform init
   terraform plan
   terraform apply
   ```

4. **Deploy External Secrets Module:**
   ```sh
   cd infra/terraform/2_external-secrets
   terraform init
   terraform plan
   terraform apply
   ```

5. **Apply External Secrets YAML:**
   ```sh
   cd infra
   kubectl apply -f external-secrets.yaml
   ```

6. **Deploy Helm Packages Module:**
   ```sh
   cd infra/terraform/3_helm
   terraform init
   terraform plan
   terraform apply
   ```

7. **Apply Kubernetes Manifests for Artemis App via Kustomize:**
   ```sh
   cd src/main/kubernetes/artemis
   kubectl apply -k .
   ```

8. **Access the application via port-forwarding:**
   ```sh
   kubectl port-forward service/artemis-app-service 8080:8080 -n online-ide
   ```

## Cilium and Hubble Setup

### Preparing Nodes for Cilium Installation

Apply a taint to ensure pods are not scheduled on nodes until Cilium is ready:

```bash
kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name | while read NODE_NAME; do
  echo "Tainting node $NODE_NAME..."
  kubectl taint nodes $NODE_NAME node.cilium.io/agent-not-ready=true:NoExecute --overwrite
done

kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

### Get Cluster CIDR Information

```bash
NATIVE_CIDR="$(gcloud container clusters describe "${NAME}" --zone "${ZONE}" --format 'value(clusterIpv4Cidr)')"
echo $NATIVE_CIDR
```

This is inserted in `ipv4NativeRoutingCIDR` in `cilium-values.yaml`.

### Installing Hubble CLI

```bash
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all "https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz"{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
```

### Using Hubble for Network Monitoring

```bash
# Start relay
cilium hubble port-forward &

# Monitor traffic in the Artemis namespace
hubble observe --namespace artemis

# Filter by port (e.g. MySQL)
hubble observe --port 3306 --namespace artemis
```

### Observed Network Communications

| Source | Destination | Port | Protocol | Notes |
|--------|-------------|------|----------|-------|
| Kafka | Zookeeper | 2181 | TCP | Kafka connects to Zookeeper for coordination |
| Artemis | MySQL | 3306 | TCP | Artemis connects directly to MySQL database |
| JHipster Registry | JHipster Registry | 8761 | TCP | Registry pods communicate with each other |
| Gateway | JHipster Registry | 8761 | TCP | Gateway connects to Registry for service discovery |

### Expected Communications (Based on Configuration)

| Source | Destination | Port | Protocol | Notes |
|--------|-------------|------|----------|-------|
| Artemis | Kafka | 9092 | TCP | Environment variables configured, but traffic not observed |
| Artemis | JHipster Registry | 8761 | TCP | Not observed in current monitoring |

### Network Connectivity Tests

```sh
nc -zv zookeeper 2181
nc -zv artemis-mysql 3306
```

## Storing Secrets

1. **Add secrets to Google Cloud Secrets Manager:**
    - Store all secrets required by your Kubernetes workloads in Google Cloud Secrets Manager.
    - Use the prefix `OIDE_` for online-ide project secrets and `ARTEMIS_` for artemis project secrets.

2. **Create an ExternalSecret object (not a plain Kubernetes secret):**

    Example:
    ```yaml
    apiVersion: external-secrets.io/v1
    kind: ExternalSecret
    metadata:
       name: gitlab-read
       namespace: external-secrets # Do not change this
       annotations:
          reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
          reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
          reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "online-ide"
    spec:
       refreshInterval: "1m"
       secretStoreRef:
          name: gcp-secret-manager
          kind: SecretStore
       target:
          name: gitlab-read
          creationPolicy: Owner
       data:
          - secretKey: .dockerconfigjson
            remoteRef:
               key: "GITLAB_READ_DOCKERCONFIGJSON"
    ```

3. Secrets are created in the `external-secrets` namespace and automatically reflected to the `online-ide` namespace using reflector annotations.

## Adding Images

1. Ensure the registry prefix is whitelisted in `src/main/kubernetes/artemis/policy/no-unknown-registry-constraint.yml`.
2. Also allow the registry in Connaisseur at `infra/terraform/3_helm/values/connaisseur-values.yaml` if not already listed.

## Image Signing with Cosign & Signature Validation with Connaisseur

All custom images are automatically built and signed during CI using Cosign and a private key, as defined in `.container-sign-template`.

Connaisseur intercepts all CREATE and UPDATE requests for Kubernetes resources and validates image signatures before allowing resource creation or updates.

Configuration: `infra/terraform/3_helm/values/connaisseur-values.yaml`

### How to Test Image Validation

- **Unsigned image (should fail):**
   ```sh
   kubectl run demo --image=docker.io/securesystemsengineering/testimage:unsigned
   ```

- **Signed image (should pass):**
   ```sh
   kubectl run ui --image=gitlab.lrz.de:5005/container-security-wizards/artemis/artemis:96ea902d
   ```

## Trivy Operator in K8s Cluster

Trivy Operator has been installed as a Helm release using Terraform.

Check generated CRDs:
```sh
kubectl get crds | grep aquasecurity.github.io
```

View vulnerability reports:
```sh
kubectl get vulnerabilityreports -n trivy
kubectl describe vulnerabilityreport <report-name> -n trivy
```
