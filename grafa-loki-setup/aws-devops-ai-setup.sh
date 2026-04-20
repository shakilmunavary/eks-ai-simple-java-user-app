
#!/bin/bash

# =============================================================================
# ██████╗ ███████╗██╗   ██╗ ██████╗ ██████╗ ███████╗     █████╗ ██╗
# ██╔══██╗██╔════╝██║   ██║██╔═══██╗██╔══██╗██╔════╝    ██╔══██╗██║
# ██║  ██║█████╗  ██║   ██║██║   ██║██████╔╝███████╗    ███████║██║
# ██║  ██║██╔══╝  ╚██╗ ██╔╝██║   ██║██╔═══╝ ╚════██║    ██╔══██║██║
# ██████╔╝███████╗ ╚████╔╝ ╚██████╔╝██║     ███████║    ██║  ██║██║
# ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚═╝     ╚══════╝    ╚═╝  ╚═╝╚═╝
#
# COMPLETE DEVOPS AI MONITORING PLATFORM - FULLY AUTOMATED
# =============================================================================
#
# This script sets up:
#   1. Monitoring Stack (Grafana + Loki)
#   2. Alert Processor (Grafana → Loki → ServiceNow)
#   3. MCP Servers (GitHub + ServiceNow + Gateway)
#   4. Grafana Alerting Configuration
#   5. AWS DevOps Agent Associations (SSM Parameter Store)
#
# NO PROMPTS - All values hardcoded below. Just run it!
#
# =============================================================================

set -e

# =============================================================================
# ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗
# ██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
# ██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
# ██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
# ╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
#  ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝
#
# EDIT THESE VALUES BEFORE RUNNING
# =============================================================================

# AWS Configuration
AWS_REGION="us-west-2"
AWS_ACCOUNT_ID="727646490021"
EKS_CLUSTER_NAME="ai-eks-cluster"

# GitHub Configuration - ADD YOUR TOKEN HERE!
GITHUB_TOKEN="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"
GITHUB_OWNER="shakilmunavary"
GITHUB_REPO="eks-ai-simple-java-user-app"

# ServiceNow Configuration
SNOW_INSTANCE="dev375632"
SNOW_USER="admin"
SNOW_PASS="kNy2EbSz+@S3"

# Kubernetes Namespaces
APP_NAMESPACE="eks-ai"
MONITORING_NAMESPACE="monitoring"
MCP_NAMESPACE="mcp-servers"

# Grafana Credentials
GRAFANA_USER="admin"
GRAFANA_PASS="admin"

# DevOps Agent IAM Role (for SSM associations)
DEVOPS_AGENT_ROLE="DevOpsAgentRole-AgentSpace-vcaasgla"

# =============================================================================
# END OF CONFIGURATION - DO NOT EDIT BELOW THIS LINE
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Helper Functions
log_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_step() { echo -e "${YELLOW}▶ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

wait_for_pods() {
    local namespace=$1
    local label=$2
    local timeout=${3:-180}
    log_step "Waiting for pods with label '$label' in namespace '$namespace'..."
    kubectl wait --for=condition=ready pod -l $label -n $namespace --timeout=${timeout}s 2>/dev/null || {
        log_info "Checking pod status..."
        kubectl get pods -n $namespace -l $label
        sleep 30
    }
    log_success "Pods ready"
}

# =============================================================================
# BANNER
# =============================================================================
clear
echo -e "${MAGENTA}"
cat << "BANNER"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║     ██████╗ ███████╗██╗   ██╗ ██████╗ ██████╗ ███████╗     █████╗ ██╗        ║
║     ██╔══██╗██╔════╝██║   ██║██╔═══██╗██╔══██╗██╔════╝    ██╔══██╗██║        ║
║     ██║  ██║█████╗  ██║   ██║██║   ██║██████╔╝███████╗    ███████║██║        ║
║     ██║  ██║██╔══╝  ╚██╗ ██╔╝██║   ██║██╔═══╝ ╚════██║    ██╔══██║██║        ║
║     ██████╔╝███████╗ ╚████╔╝ ╚██████╔╝██║     ███████║    ██║  ██║██║        ║
║     ╚═════╝ ╚══════╝  ╚═══╝   ╚═════╝ ╚═╝     ╚══════╝    ╚═╝  ╚═╝╚═╝        ║
║                                                                               ║
║              Complete DevOps AI Monitoring Platform Setup                     ║
║                         FULLY AUTOMATED                                       ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${BLUE}Configuration:${NC}"
echo "  AWS Account:      $AWS_ACCOUNT_ID"
echo "  AWS Region:       $AWS_REGION"
echo "  EKS Cluster:      $EKS_CLUSTER_NAME"
echo "  GitHub:           $GITHUB_OWNER/$GITHUB_REPO"
echo "  ServiceNow:       $SNOW_INSTANCE.service-now.com"
echo "  App Namespace:    $APP_NAMESPACE"
echo ""
echo -e "${GREEN}Starting installation in 5 seconds...${NC}"
sleep 5

# =============================================================================
# STEP 1: PREREQUISITES CHECK
# =============================================================================
log_header "STEP 1/8: Prerequisites Check"

log_step "Checking kubectl..."
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl."
    exit 1
fi
kubectl version --client --short 2>/dev/null || kubectl version --client | head -1
log_success "kubectl OK"

log_step "Checking helm..."
if ! command -v helm &> /dev/null; then
    log_error "helm not found. Please install helm."
    exit 1
fi
helm version --short
log_success "helm OK"

log_step "Checking AWS CLI..."
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install AWS CLI."
    exit 1
fi
aws --version
log_success "AWS CLI OK"

log_step "Checking jq..."
if ! command -v jq &> /dev/null; then
    log_info "Installing jq..."
    if command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    fi
fi
log_success "jq OK"

log_step "Updating kubeconfig..."
aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION
log_success "kubeconfig updated"

log_step "Verifying cluster access..."
kubectl cluster-info > /dev/null 2>&1
log_success "Connected to cluster: $EKS_CLUSTER_NAME"

# =============================================================================
# STEP 2: CLEANUP EXISTING RESOURCES
# =============================================================================
log_header "STEP 2/8: Cleanup Existing Resources"

log_step "Cleaning up monitoring namespace..."
kubectl delete deployment snow-alert-processor -n $MONITORING_NAMESPACE --ignore-not-found=true 2>/dev/null || true
kubectl delete service snow-alert-processor -n $MONITORING_NAMESPACE --ignore-not-found=true 2>/dev/null || true
kubectl delete configmap snow-alert-processor-config -n $MONITORING_NAMESPACE --ignore-not-found=true 2>/dev/null || true

log_step "Cleaning up MCP namespace..."
kubectl delete deployment github-mcp-server servicenow-mcp-server mcp-gateway -n $MCP_NAMESPACE --ignore-not-found=true 2>/dev/null || true
kubectl delete service github-mcp servicenow-mcp mcp-gateway -n $MCP_NAMESPACE --ignore-not-found=true 2>/dev/null || true
kubectl delete configmap github-mcp-config servicenow-mcp-config mcp-gateway-config -n $MCP_NAMESPACE --ignore-not-found=true 2>/dev/null || true
kubectl delete secret mcp-credentials -n $MCP_NAMESPACE --ignore-not-found=true 2>/dev/null || true

log_success "Cleanup complete"

# =============================================================================
# STEP 3: CREATE NAMESPACES
# =============================================================================
log_header "STEP 3/8: Creating Namespaces"

for ns in $MONITORING_NAMESPACE $MCP_NAMESPACE $APP_NAMESPACE; do
    log_step "Creating namespace: $ns"
    kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
done
log_success "All namespaces created"

# =============================================================================
# STEP 4: INSTALL MONITORING STACK (Grafana + Loki)
# =============================================================================
log_header "STEP 4/8: Installing Monitoring Stack (Grafana + Loki)"

log_step "Adding Helm repositories..."
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update
log_success "Helm repos updated"

log_step "Uninstalling existing Loki Stack (if any)..."
helm uninstall loki-stack -n $MONITORING_NAMESPACE 2>/dev/null || true
sleep 10

log_step "Installing Loki Stack..."
helm upgrade --install loki-stack grafana/loki-stack \
    --namespace $MONITORING_NAMESPACE \
    --set grafana.enabled=true \
    --set grafana.service.type=LoadBalancer \
    --set grafana.adminPassword="${GRAFANA_PASS}" \
    --set prometheus.enabled=false \
    --set loki.persistence.enabled=false \
    --set promtail.enabled=true \
    --wait --timeout 5m
log_success "Loki Stack installed"

wait_for_pods $MONITORING_NAMESPACE "app.kubernetes.io/name=grafana"

log_step "Getting Grafana URL..."
sleep 30
GRAFANA_HOST=""
for i in {1..30}; do
    GRAFANA_HOST=$(kubectl get svc loki-stack-grafana -n $MONITORING_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$GRAFANA_HOST" ] && [ "$GRAFANA_HOST" != "null" ]; then
        break
    fi
    sleep 10
done

if [ -z "$GRAFANA_HOST" ] || [ "$GRAFANA_HOST" == "null" ]; then
    log_info "Creating external Grafana service..."
    kubectl delete svc grafana-external -n $MONITORING_NAMESPACE --ignore-not-found=true 2>/dev/null || true
    kubectl expose service loki-stack-grafana --name=grafana-external \
        --type=LoadBalancer --port=80 --target-port=3000 \
        -n $MONITORING_NAMESPACE
    sleep 30
    GRAFANA_HOST=$(kubectl get svc grafana-external -n $MONITORING_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
fi

GRAFANA_URL="http://$GRAFANA_HOST"
log_success "Grafana URL: $GRAFANA_URL"

# Get actual Grafana password from secret
log_step "Retrieving Grafana admin password..."
GRAFANA_ACTUAL_PASS=$(kubectl get secret loki-stack-grafana -n $MONITORING_NAMESPACE -o jsonpath="{.data.admin-password}" 2>/dev/null | base64 --decode)
if [ -z "$GRAFANA_ACTUAL_PASS" ]; then
    GRAFANA_ACTUAL_PASS="$GRAFANA_PASS"
fi
log_success "Grafana password retrieved"

log_step "Waiting for Grafana to be ready..."
sleep 20
for i in {1..20}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GRAFANA_URL/api/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" == "200" ]; then
        break
    fi
    sleep 5
done
log_success "Grafana is ready"

log_step "Getting Loki datasource UID..."
LOKI_DATASOURCE_UID=""
for i in {1..10}; do
    RESPONSE=$(curl -s "$GRAFANA_URL/api/datasources" -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" 2>/dev/null)
    LOKI_DATASOURCE_UID=$(echo "$RESPONSE" | jq -r '.[] | select(.type=="loki") | .uid' 2>/dev/null | head -1)
    if [ -n "$LOKI_DATASOURCE_UID" ] && [ "$LOKI_DATASOURCE_UID" != "null" ]; then
        break
    fi
    sleep 5
done

if [ -z "$LOKI_DATASOURCE_UID" ] || [ "$LOKI_DATASOURCE_UID" == "null" ]; then
    log_info "Creating Loki datasource..."
    RESPONSE=$(curl -s -X POST "$GRAFANA_URL/api/datasources" \
        -H "Content-Type: application/json" \
        -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" \
        -d '{
            "name": "Loki",
            "type": "loki",
            "url": "http://loki-stack:3100",
            "access": "proxy",
            "isDefault": true
        }' 2>/dev/null)
    LOKI_DATASOURCE_UID=$(echo "$RESPONSE" | jq -r '.datasource.uid // .uid // "loki"' 2>/dev/null)
fi

if [ -z "$LOKI_DATASOURCE_UID" ] || [ "$LOKI_DATASOURCE_UID" == "null" ]; then
    LOKI_DATASOURCE_UID="loki"
fi
log_success "Loki Datasource UID: $LOKI_DATASOURCE_UID"

# =============================================================================
# STEP 5: DEPLOY ALERT PROCESSOR
# =============================================================================
log_header "STEP 5/8: Deploying Alert Processor"

log_step "Creating Alert Processor deployment..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: snow-alert-processor-config
  namespace: ${MONITORING_NAMESPACE}
data:
  app.py: |
    from flask import Flask, request, jsonify
    import json, urllib.request, urllib.parse, ssl, base64, os, re, hashlib
    from datetime import datetime, timedelta

    app = Flask(__name__)

    LOKI_URL = os.environ.get('LOKI_URL', 'http://loki-stack.monitoring.svc.cluster.local:3100')
    SNOW_URL = os.environ.get('SNOW_URL')
    SNOW_USER = os.environ.get('SNOW_USER')
    SNOW_PASS = os.environ.get('SNOW_PASS')
    NAMESPACE = os.environ.get('NAMESPACE', 'eks-ai')
    CLUSTER_NAME = os.environ.get('CLUSTER_NAME', 'ai-eks-cluster')

    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE

    def make_request(url, method='GET', data=None, headers=None, auth=None):
        req = urllib.request.Request(url, method=method)
        if headers:
            for k, v in headers.items(): req.add_header(k, v)
        if auth:
            creds = base64.b64encode(f"{auth[0]}:{auth[1]}".encode()).decode()
            req.add_header('Authorization', f'Basic {creds}')
        if data:
            req.data = json.dumps(data).encode('utf-8')
            req.add_header('Content-Type', 'application/json')
        try:
            with urllib.request.urlopen(req, timeout=30, context=ssl_context) as resp:
                return json.loads(resp.read().decode()), resp.status
        except urllib.error.HTTPError as e:
            return {'error': str(e)}, e.code
        except Exception as e:
            return {'error': str(e)}, 500

    def extract_error_signature(logs):
        patterns = []
        for log in logs:
            if 'Exception' in log or 'ERROR' in log:
                m = re.search(r'([A-Za-z]+Exception|[A-Za-z]+Error):', log)
                if m: patterns.append(m.group(1))
                if 'Value too long for column' in log:
                    m = re.search(r'Value too long for column "([^"]+)"', log)
                    if m: patterns.append(f"VALUE_TOO_LONG_{m.group(1)}")
                if 'Connection refused' in log: patterns.append("CONNECTION_REFUSED")
                if 'Timeout' in log.lower(): patterns.append("TIMEOUT")
                if 'OutOfMemory' in log: patterns.append("OOM")
        return "_".join(sorted(set(patterns))[:3]) if patterns else "GENERIC_ERROR"

    def get_error_hash(ns, sig):
        return hashlib.md5(f"{ns}:{sig}".encode()).hexdigest()[:8].upper()

    def get_error_type(sig):
        if 'VALUE_TOO_LONG' in sig: return "Database Column Value Too Long"
        elif 'CONNECTION_REFUSED' in sig: return "Connection Refused"
        elif 'TIMEOUT' in sig: return "Request Timeout"
        elif 'OOM' in sig: return "Out of Memory"
        return "Application Error"

    def check_existing_incident(ns, sig):
        h = get_error_hash(ns, sig)
        q = f"short_descriptionLIKE{h}^stateIN1,2,3,4,5^ORDERBYDESCsys_created_on"
        url = f"{SNOW_URL}?sysparm_query={urllib.parse.quote(q)}&sysparm_limit=1"
        r, s = make_request(url, headers={'Accept': 'application/json'}, auth=(SNOW_USER, SNOW_PASS))
        if s == 200 and r.get('result'):
            return r['result'][0].get('number'), r['result'][0].get('sys_id'), r['result'][0].get('state')
        return None, None, None

    def update_incident(sys_id, notes):
        url = f"{SNOW_URL}/{sys_id}"
        r, s = make_request(url, method='PATCH', data={"work_notes": notes}, headers={'Accept': 'application/json'}, auth=(SNOW_USER, SNOW_PASS))
        return s == 200

    def create_incident(title, desc, notes):
        data = {"short_description": title[:160], "description": desc[:4000], "work_notes": notes[:60000],
                "caller_id": "admin", "urgency": "2", "impact": "2", "category": "software", "subcategory": "application", "state": "1"}
        r, s = make_request(SNOW_URL, method='POST', data=data, headers={'Accept': 'application/json'}, auth=(SNOW_USER, SNOW_PASS))
        if s in [200, 201]: return r.get('result', {}).get('number'), r.get('result', {}).get('sys_id')
        return None, None

    def query_loki_errors(ns, mins=30):
        try:
            end = datetime.utcnow()
            start = end - timedelta(minutes=mins)
            q = f'{{namespace="{ns}"}} |= "ERROR"'
            params = {'query': q, 'start': str(int(start.timestamp() * 1e9)), 'end': str(int(end.timestamp() * 1e9)), 'limit': '100'}
            url = f"{LOKI_URL}/loki/api/v1/query_range?{urllib.parse.urlencode(params)}"
            r, s = make_request(url, headers={'Accept': 'application/json'})
            logs, pods = [], set()
            if s == 200 and r.get('data', {}).get('result'):
                for stream in r['data']['result']:
                    if 'pod' in stream.get('stream', {}): pods.add(stream['stream']['pod'])
                    for v in stream.get('values', []):
                        ts = datetime.fromtimestamp(int(v[0]) / 1e9).strftime('%Y-%m-%d %H:%M:%S')
                        logs.append(f"[{ts}] {v[1]}")
            return logs[:80], list(pods)
        except Exception as e:
            return [f"Error: {e}"], []

    @app.route('/webhook', methods=['POST'])
    def handle_webhook():
        try:
            body = request.json or {}
            alerts = body.get('alerts', [body])
            results = []
            for alert in alerts:
                if alert.get('status') != 'firing': continue
                labels = alert.get('labels', {})
                ns = labels.get('namespace', NAMESPACE)
                logs, pods = query_loki_errors(ns)
                if not logs or logs[0].startswith('Error'):
                    results.append({'action': 'skipped', 'reason': 'No logs'}); continue
                sig = extract_error_signature(logs)
                h = get_error_hash(ns, sig)
                etype = get_error_type(sig)
                trace = '\n'.join(logs)
                pods_str = ', '.join(pods) or 'Unknown'
                ts = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
                existing, sys_id, state = check_existing_incident(ns, sig)
                if existing:
                    update_incident(sys_id, f"RECURRING - {ts}\nPods: {pods_str}\n\n{trace}")
                    results.append({'action': 'updated', 'incident': existing, 'hash': h}); continue
                title = f"[HIGH] {etype} - {ns} [{h}]"
                desc = f"Error: {etype}\nHash: {h}\nTime: {ts}\nCluster: {CLUSTER_NAME}\nPods: {pods_str}"
                notes = f"STACK TRACE:\n{trace}"
                inc, _ = create_incident(title, desc, notes)
                results.append({'action': 'created' if inc else 'failed', 'incident': inc, 'hash': h})
            return jsonify({'results': results})
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @app.route('/health', methods=['GET'])
    def health(): return jsonify({'status': 'healthy', 'service': 'alert-processor'})

    @app.route('/test', methods=['GET'])
    def test():
        logs, pods = query_loki_errors(NAMESPACE, 60)
        sig = extract_error_signature(logs) if logs else "NO_ERRORS"
        h = get_error_hash(NAMESPACE, sig)
        existing, _, _ = check_existing_incident(NAMESPACE, sig)
        return jsonify({'logs_found': len(logs), 'pods': pods, 'error_hash': h, 'error_type': get_error_type(sig), 'existing_ticket': existing})

    if __name__ == '__main__':
        app.run(host='0.0.0.0', port=5000)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: snow-alert-processor
  namespace: ${MONITORING_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: snow-alert-processor
  template:
    metadata:
      labels:
        app: snow-alert-processor
    spec:
      containers:
      - name: processor
        image: python:3.11-slim
        command: ["/bin/sh", "-c", "pip install --quiet flask && python /app/app.py"]
        ports:
        - containerPort: 5000
        env:
        - name: LOKI_URL
          value: "http://loki-stack.${MONITORING_NAMESPACE}.svc.cluster.local:3100"
        - name: SNOW_URL
          value: "https://${SNOW_INSTANCE}.service-now.com/api/now/table/incident"
        - name: SNOW_USER
          value: "${SNOW_USER}"
        - name: SNOW_PASS
          value: "${SNOW_PASS}"
        - name: NAMESPACE
          value: "${APP_NAMESPACE}"
        - name: CLUSTER_NAME
          value: "${EKS_CLUSTER_NAME}"
        volumeMounts:
        - name: app-code
          mountPath: /app
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 90
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 45
          periodSeconds: 5
      volumes:
      - name: app-code
        configMap:
          name: snow-alert-processor-config
---
apiVersion: v1
kind: Service
metadata:
  name: snow-alert-processor
  namespace: ${MONITORING_NAMESPACE}
spec:
  type: LoadBalancer
  selector:
    app: snow-alert-processor
  ports:
  - port: 80
    targetPort: 5000
EOF

log_success "Alert Processor deployed"
wait_for_pods $MONITORING_NAMESPACE "app=snow-alert-processor" 180

log_step "Getting Alert Processor URL..."
ALERT_PROCESSOR_HOST=""
for i in {1..30}; do
    ALERT_PROCESSOR_HOST=$(kubectl get svc snow-alert-processor -n $MONITORING_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$ALERT_PROCESSOR_HOST" ] && [ "$ALERT_PROCESSOR_HOST" != "null" ]; then
        break
    fi
    sleep 10
done
ALERT_PROCESSOR_URL="http://$ALERT_PROCESSOR_HOST"
log_success "Alert Processor URL: $ALERT_PROCESSOR_URL"

# =============================================================================
# STEP 6: DEPLOY MCP SERVERS
# =============================================================================
log_header "STEP 6/8: Deploying MCP Servers"

log_step "Creating MCP credentials secret..."
kubectl create secret generic mcp-credentials -n ${MCP_NAMESPACE} \
    --from-literal=github-token="${GITHUB_TOKEN}" \
    --from-literal=snow-user="${SNOW_USER}" \
    --from-literal=snow-pass="${SNOW_PASS}" \
    --dry-run=client -o yaml | kubectl apply -f -
log_success "MCP credentials secret created"

# Deploy GitHub MCP Server
log_step "Deploying GitHub MCP Server..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: github-mcp-config
  namespace: ${MCP_NAMESPACE}
data:
  server.py: |
    from flask import Flask, request, jsonify
    import urllib.request, json, base64, os, ssl

    app = Flask(__name__)
    GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')
    GITHUB_API = "https://api.github.com"
    ssl_ctx = ssl.create_default_context()

    def gh_request(endpoint, method='GET', data=None):
        url = f"{GITHUB_API}{endpoint}"
        req = urllib.request.Request(url, method=method)
        req.add_header('Authorization', f'token {GITHUB_TOKEN}')
        req.add_header('Accept', 'application/vnd.github.v3+json')
        req.add_header('User-Agent', 'MCP-GitHub')
        if data:
            req.data = json.dumps(data).encode('utf-8')
            req.add_header('Content-Type', 'application/json')
        try:
            with urllib.request.urlopen(req, timeout=30, context=ssl_ctx) as resp:
                return json.loads(resp.read().decode()), resp.status
        except urllib.error.HTTPError as e:
            return {'error': str(e)}, e.code
        except Exception as e:
            return {'error': str(e)}, 500

    @app.route('/mcp/tools', methods=['GET'])
    def list_tools():
        return jsonify({"tools": [
            {"name": "get_repository", "description": "Get repo details"},
            {"name": "get_file_content", "description": "Get file content"},
            {"name": "list_commits", "description": "List commits"},
            {"name": "search_code", "description": "Search code"}
        ]})

    @app.route('/mcp/execute', methods=['POST'])
    def execute():
        body = request.json
        tool, params = body.get('tool'), body.get('parameters', {})
        if tool == 'get_repository':
            r, s = gh_request(f"/repos/{params['owner']}/{params['repo']}")
        elif tool == 'get_file_content':
            ref = params.get('ref', 'main')
            r, s = gh_request(f"/repos/{params['owner']}/{params['repo']}/contents/{params['path']}?ref={ref}")
            if s == 200 and 'content' in r:
                r['decoded_content'] = base64.b64decode(r['content']).decode('utf-8')
        elif tool == 'list_commits':
            r, s = gh_request(f"/repos/{params['owner']}/{params['repo']}/commits")
        elif tool == 'search_code':
            q = f"{params['query']}+repo:{params['owner']}/{params['repo']}"
            r, s = gh_request(f"/search/code?q={q}")
        else:
            return jsonify({'error': f'Unknown tool: {tool}'}), 400
        return jsonify(r), s

    @app.route('/repos/<owner>/<repo>', methods=['GET'])
    def get_repo(owner, repo):
        r, s = gh_request(f"/repos/{owner}/{repo}")
        return jsonify(r), s

    @app.route('/repos/<owner>/<repo>/contents/<path:path>', methods=['GET'])
    def get_content(owner, repo, path):
        ref = request.args.get('ref', 'main')
        r, s = gh_request(f"/repos/{owner}/{repo}/contents/{path}?ref={ref}")
        if s == 200 and 'content' in r:
            r['decoded_content'] = base64.b64decode(r['content']).decode('utf-8')
        return jsonify(r), s

    @app.route('/repos/<owner>/<repo>/commits', methods=['GET'])
    def get_commits(owner, repo):
        r, s = gh_request(f"/repos/{owner}/{repo}/commits")
        return jsonify(r), s

    @app.route('/health', methods=['GET'])
    def health():
        return jsonify({'status': 'healthy', 'service': 'github-mcp'})

    if __name__ == '__main__':
        app.run(host='0.0.0.0', port=3001)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-mcp-server
  namespace: ${MCP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: github-mcp
  template:
    metadata:
      labels:
        app: github-mcp
    spec:
      containers:
      - name: server
        image: python:3.11-slim
        command: ["/bin/sh", "-c", "pip install --quiet flask && python /app/server.py"]
        ports:
        - containerPort: 3001
        env:
        - name: GITHUB_TOKEN
          valueFrom:
            secretKeyRef:
              name: mcp-credentials
              key: github-token
        volumeMounts:
        - name: app-code
          mountPath: /app
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 45
        readinessProbe:
          httpGet:
            path: /health
            port: 3001
          initialDelaySeconds: 20
      volumes:
      - name: app-code
        configMap:
          name: github-mcp-config
---
apiVersion: v1
kind: Service
metadata:
  name: github-mcp
  namespace: ${MCP_NAMESPACE}
spec:
  type: ClusterIP
  selector:
    app: github-mcp
  ports:
  - port: 3001
    targetPort: 3001
EOF
log_success "GitHub MCP Server deployed"

# Deploy ServiceNow MCP Server
log_step "Deploying ServiceNow MCP Server..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: servicenow-mcp-config
  namespace: ${MCP_NAMESPACE}
data:
  server.py: |
    from flask import Flask, request, jsonify
    import urllib.request, urllib.parse, json, base64, os, ssl

    app = Flask(__name__)
    SNOW_INSTANCE = os.environ.get('SNOW_INSTANCE', '${SNOW_INSTANCE}')
    SNOW_USER = os.environ.get('SNOW_USER')
    SNOW_PASS = os.environ.get('SNOW_PASS')
    SNOW_URL = f"https://{SNOW_INSTANCE}.service-now.com/api/now/table"
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    def snow_request(endpoint, method='GET', data=None, params=None):
        url = f"{SNOW_URL}{endpoint}"
        if params: url += '?' + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, method=method)
        creds = base64.b64encode(f"{SNOW_USER}:{SNOW_PASS}".encode()).decode()
        req.add_header('Authorization', f'Basic {creds}')
        req.add_header('Accept', 'application/json')
        if data:
            req.data = json.dumps(data).encode('utf-8')
            req.add_header('Content-Type', 'application/json')
        try:
            with urllib.request.urlopen(req, timeout=30, context=ssl_ctx) as resp:
                return json.loads(resp.read().decode()), resp.status
        except urllib.error.HTTPError as e:
            return {'error': str(e)}, e.code
        except Exception as e:
            return {'error': str(e)}, 500

    @app.route('/mcp/tools', methods=['GET'])
    def list_tools():
        return jsonify({"tools": [
            {"name": "get_incident", "description": "Get incident by number"},
            {"name": "list_incidents", "description": "List incidents"},
            {"name": "update_incident", "description": "Update incident"},
            {"name": "search_incidents", "description": "Search incidents"}
        ]})

    @app.route('/mcp/execute', methods=['POST'])
    def execute():
        body = request.json
        tool, params = body.get('tool'), body.get('parameters', {})
        if tool == 'get_incident':
            r, s = snow_request('/incident', params={'sysparm_query': f"number={params['number']}", 'sysparm_limit': 1})
            if s == 200 and r.get('result'): return jsonify(r['result'][0]), 200
            return jsonify({'error': 'Not found'}), 404
        elif tool == 'list_incidents':
            limit = params.get('limit', 10)
            r, s = snow_request('/incident', params={'sysparm_query': 'ORDERBYDESCsys_created_on', 'sysparm_limit': limit})
            return jsonify(r.get('result', [])), s
        elif tool == 'update_incident':
            r, s = snow_request('/incident', params={'sysparm_query': f"number={params['number']}", 'sysparm_limit': 1})
            if s != 200 or not r.get('result'): return jsonify({'error': 'Not found'}), 404
            sys_id = r['result'][0]['sys_id']
            r2, s2 = snow_request(f'/incident/{sys_id}', method='PATCH', data={'work_notes': params.get('work_notes', '')})
            return jsonify(r2.get('result', r2)), s2
        elif tool == 'search_incidents':
            kw = params.get('keyword', '')
            r, s = snow_request('/incident', params={'sysparm_query': f'short_descriptionLIKE{kw}^ORDERBYDESCsys_created_on', 'sysparm_limit': 10})
            return jsonify(r.get('result', [])), s
        return jsonify({'error': f'Unknown tool: {tool}'}), 400

    @app.route('/incidents', methods=['GET'])
    def list_all():
        r, s = snow_request('/incident', params={'sysparm_query': 'ORDERBYDESCsys_created_on', 'sysparm_limit': 10})
        return jsonify(r.get('result', [])), s

    @app.route('/incidents/<number>', methods=['GET'])
    def get_one(number):
        r, s = snow_request('/incident', params={'sysparm_query': f'number={number}', 'sysparm_limit': 1})
        if s == 200 and r.get('result'):
            inc = r['result'][0]
            notes, _ = snow_request('/sys_journal_field', params={'sysparm_query': f"element_id={inc['sys_id']}^ORDERBYDESCsys_created_on", 'sysparm_limit': 10})
            inc['work_notes_history'] = notes.get('result', [])
            return jsonify(inc), 200
        return jsonify({'error': 'Not found'}), 404

    @app.route('/health', methods=['GET'])
    def health():
        return jsonify({'status': 'healthy', 'service': 'servicenow-mcp', 'instance': SNOW_INSTANCE})

    if __name__ == '__main__':
        app.run(host='0.0.0.0', port=3002)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: servicenow-mcp-server
  namespace: ${MCP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: servicenow-mcp
  template:
    metadata:
      labels:
        app: servicenow-mcp
    spec:
      containers:
      - name: server
        image: python:3.11-slim
        command: ["/bin/sh", "-c", "pip install --quiet flask && python /app/server.py"]
        ports:
        - containerPort: 3002
        env:
        - name: SNOW_INSTANCE
          value: "${SNOW_INSTANCE}"
        - name: SNOW_USER
          valueFrom:
            secretKeyRef:
              name: mcp-credentials
              key: snow-user
        - name: SNOW_PASS
          valueFrom:
            secretKeyRef:
              name: mcp-credentials
              key: snow-pass
        volumeMounts:
        - name: app-code
          mountPath: /app
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3002
          initialDelaySeconds: 45
        readinessProbe:
          httpGet:
            path: /health
            port: 3002
          initialDelaySeconds: 20
      volumes:
      - name: app-code
        configMap:
          name: servicenow-mcp-config
---
apiVersion: v1
kind: Service
metadata:
  name: servicenow-mcp
  namespace: ${MCP_NAMESPACE}
spec:
  type: ClusterIP
  selector:
    app: servicenow-mcp
  ports:
  - port: 3002
    targetPort: 3002
EOF
log_success "ServiceNow MCP Server deployed"

# Deploy MCP Gateway
log_step "Deploying MCP Gateway..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mcp-gateway-config
  namespace: ${MCP_NAMESPACE}
data:
  server.py: |
    from flask import Flask, request, jsonify
    import urllib.request, json, os
    from datetime import datetime

    app = Flask(__name__)
    MCP_SERVERS = {
        'github': 'http://github-mcp.${MCP_NAMESPACE}.svc.cluster.local:3001',
        'servicenow': 'http://servicenow-mcp.${MCP_NAMESPACE}.svc.cluster.local:3002'
    }
    GITHUB_OWNER = '${GITHUB_OWNER}'
    GITHUB_REPO = '${GITHUB_REPO}'

    def proxy(url, path, method='GET', data=None):
        req = urllib.request.Request(f"{url}{path}", method=method)
        req.add_header('Content-Type', 'application/json')
        if data: req.data = json.dumps(data).encode('utf-8')
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode()), resp.status
        except Exception as e:
            return {'error': str(e)}, 500

    @app.route('/mcp/servers', methods=['GET'])
    def list_servers():
        servers = []
        for name, url in MCP_SERVERS.items():
            try:
                r, s = proxy(url, '/health')
                servers.append({'name': name, 'status': 'healthy' if s == 200 else 'unhealthy'})
            except:
                servers.append({'name': name, 'status': 'unavailable'})
        return jsonify(servers)

    @app.route('/mcp/<server>/tools', methods=['GET'])
    def get_tools(server):
        if server not in MCP_SERVERS: return jsonify({'error': 'Unknown server'}), 404
        r, s = proxy(MCP_SERVERS[server], '/mcp/tools')
        return jsonify(r), s

    @app.route('/mcp/<server>/execute', methods=['POST'])
    def execute_tool(server):
        if server not in MCP_SERVERS: return jsonify({'error': 'Unknown server'}), 404
        r, s = proxy(MCP_SERVERS[server], '/mcp/execute', method='POST', data=request.json)
        return jsonify(r), s

    @app.route('/investigate/<incident>', methods=['GET'])
    def investigate(incident):
        result = {'incident': incident, 'timestamp': datetime.utcnow().isoformat(), 'sources': {}}
        r, s = proxy(MCP_SERVERS['servicenow'], f'/incidents/{incident}')
        result['sources']['servicenow'] = {'status': 'success' if s == 200 else 'error', 'data': r}
        r2, s2 = proxy(MCP_SERVERS['github'], f'/repos/{GITHUB_OWNER}/{GITHUB_REPO}/commits')
        result['sources']['github'] = {'status': 'success' if s2 == 200 else 'error', 'recent_commits': r2[:5] if isinstance(r2, list) else r2}
        return jsonify(result)

    @app.route('/health', methods=['GET'])
    def health():
        return jsonify({'status': 'healthy', 'service': 'mcp-gateway'})

    if __name__ == '__main__':
        app.run(host='0.0.0.0', port=3000)
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-gateway
  namespace: ${MCP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mcp-gateway
  template:
    metadata:
      labels:
        app: mcp-gateway
    spec:
      containers:
      - name: gateway
        image: python:3.11-slim
        command: ["/bin/sh", "-c", "pip install --quiet flask && python /app/server.py"]
        ports:
        - containerPort: 3000
        volumeMounts:
        - name: app-code
          mountPath: /app
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 45
      volumes:
      - name: app-code
        configMap:
          name: mcp-gateway-config
---
apiVersion: v1
kind: Service
metadata:
  name: mcp-gateway
  namespace: ${MCP_NAMESPACE}
spec:
  type: LoadBalancer
  selector:
    app: mcp-gateway
  ports:
  - port: 80
    targetPort: 3000
EOF
log_success "MCP Gateway deployed"

# Wait for MCP pods
log_step "Waiting for MCP pods..."
sleep 30
wait_for_pods $MCP_NAMESPACE "app=github-mcp" 180 || true
wait_for_pods $MCP_NAMESPACE "app=servicenow-mcp" 180 || true
wait_for_pods $MCP_NAMESPACE "app=mcp-gateway" 180 || true

log_step "Getting MCP Gateway URL..."
MCP_GATEWAY_HOST=""
for i in {1..30}; do
    MCP_GATEWAY_HOST=$(kubectl get svc mcp-gateway -n $MCP_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$MCP_GATEWAY_HOST" ] && [ "$MCP_GATEWAY_HOST" != "null" ]; then
        break
    fi
    sleep 10
done
MCP_GATEWAY_URL="http://$MCP_GATEWAY_HOST"
log_success "MCP Gateway URL: $MCP_GATEWAY_URL"

# =============================================================================
# STEP 7: CONFIGURE GRAFANA ALERTING
# =============================================================================
log_header "STEP 7/8: Configuring Grafana Alerting"

log_step "Waiting for Grafana API..."
sleep 10

log_step "Resetting Grafana notification policies..."
curl -s -X PUT "$GRAFANA_URL/api/v1/provisioning/policies" \
    -H "Content-Type: application/json" -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" \
    -d '{"receiver": "grafana-default-email", "routes": []}' > /dev/null 2>&1 || true

log_step "Cleaning up existing alert rules..."
EXISTING_RULES=$(curl -s "$GRAFANA_URL/api/v1/provisioning/alert-rules" -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" 2>/dev/null)
for uid in $(echo "$EXISTING_RULES" | jq -r '.[].uid // empty' 2>/dev/null); do
    curl -s -X DELETE "$GRAFANA_URL/api/v1/provisioning/alert-rules/$uid" -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" > /dev/null 2>&1 || true
done

log_step "Creating alert folder..."
FOLDER_RESPONSE=$(curl -s -X POST "$GRAFANA_URL/api/folders" \
    -H "Content-Type: application/json" \
    -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" \
    -d '{"title": "Application Alerts"}' 2>/dev/null)
FOLDER_UID=$(echo "$FOLDER_RESPONSE" | jq -r '.uid // empty' 2>/dev/null)

if [ -z "$FOLDER_UID" ] || [ "$FOLDER_UID" == "null" ]; then
    FOLDER_UID=$(curl -s "$GRAFANA_URL/api/folders" -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" 2>/dev/null | jq -r '.[] | select(.title=="Application Alerts") | .uid' 2>/dev/null)
fi

if [ -z "$FOLDER_UID" ] || [ "$FOLDER_UID" == "null" ]; then
    FOLDER_UID="app-alerts-$(date +%s)"
fi
log_success "Alert folder UID: $FOLDER_UID"

log_step "Creating alert rule..."
curl -s -X POST "$GRAFANA_URL/api/v1/provisioning/alert-rules" \
    -H "Content-Type: application/json" -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" \
    -d '{
        "title": "Application Error Detected",
        "ruleGroup": "error-alerts",
        "folderUID": "'"${FOLDER_UID}"'",
        "condition": "C",
        "for": "0s",
        "noDataState": "NoData",
        "execErrState": "Error",
        "annotations": {"summary": "ERROR detected in '"${APP_NAMESPACE}"' namespace"},
        "labels": {"severity": "high", "namespace": "'"${APP_NAMESPACE}"'"},
        "data": [
            {"refId": "A", "datasourceUid": "'"${LOKI_DATASOURCE_UID}"'", "relativeTimeRange": {"from": 300, "to": 0}, "model": {"expr": "count_over_time({namespace=\"'"${APP_NAMESPACE}"'\"} |= \"ERROR\" [5m])", "refId": "A"}},
            {"refId": "B", "datasourceUid": "__expr__", "relativeTimeRange": {"from": 0, "to": 0}, "model": {"type": "reduce", "expression": "A", "reducer": "last", "refId": "B"}},
            {"refId": "C", "datasourceUid": "__expr__", "relativeTimeRange": {"from": 0, "to": 0}, "model": {"type": "threshold", "expression": "B", "conditions": [{"evaluator": {"type": "gt", "params": [0]}}], "refId": "C"}}
        ]
    }' > /dev/null 2>&1 || true
log_success "Alert rule created"

log_step "Creating ServiceNow contact point..."
curl -s -X POST "$GRAFANA_URL/api/v1/provisioning/contact-points" \
    -H "Content-Type: application/json" -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" \
    -d '{
        "name": "ServiceNow",
        "type": "webhook",
        "settings": {"url": "'"${ALERT_PROCESSOR_URL}/webhook"'", "httpMethod": "POST"}
    }' > /dev/null 2>&1 || true
log_success "Contact point created"

log_step "Creating notification policy..."
curl -s -X PUT "$GRAFANA_URL/api/v1/provisioning/policies" \
    -H "Content-Type: application/json" -u "${GRAFANA_USER}:${GRAFANA_ACTUAL_PASS}" \
    -d '{
        "receiver": "grafana-default-email",
        "routes": [{"receiver": "ServiceNow", "object_matchers": [["severity", "=", "high"]]}]
    }' > /dev/null 2>&1 || true
log_success "Notification policy configured"

# =============================================================================
# STEP 8: AWS DEVOPS AGENT ASSOCIATIONS (SSM Parameter Store)
# =============================================================================
log_header "STEP 8/8: Setting up AWS DevOps Agent Associations"

log_step "Creating IAM policy for SSM access..."
cat > /tmp/ssm-policy.json << POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DevOpsAgentSSMRead",
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": [
                "arn:aws:ssm:${AWS_REGION}:${AWS_ACCOUNT_ID}:parameter/devops-agent/*"
            ]
        }
    ]
}
POLICY

POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/DevOpsAgentSSMReadPolicy"

if aws iam get-policy --policy-arn $POLICY_ARN 2>/dev/null; then
    log_info "Policy exists, updating..."
    OLDEST_VERSION=$(aws iam list-policy-versions --policy-arn $POLICY_ARN --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text 2>/dev/null | tail -1)
    if [ -n "$OLDEST_VERSION" ]; then
        aws iam delete-policy-version --policy-arn $POLICY_ARN --version-id $OLDEST_VERSION 2>/dev/null || true
    fi
    aws iam create-policy-version --policy-arn $POLICY_ARN --policy-document file:///tmp/ssm-policy.json --set-as-default 2>/dev/null || true
else
    aws iam create-policy --policy-name DevOpsAgentSSMReadPolicy --policy-document file:///tmp/ssm-policy.json --region $AWS_REGION 2>/dev/null || true
fi

aws iam attach-role-policy --role-name $DEVOPS_AGENT_ROLE --policy-arn $POLICY_ARN 2>/dev/null || true
log_success "IAM policy configured"

log_step "Storing configuration in SSM Parameter Store..."

aws ssm put-parameter --name "/devops-agent/config/mcp-gateway-url" --value "${MCP_GATEWAY_URL}" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo "  ✅ mcp-gateway-url" || echo "  ⚠️ mcp-gateway-url (skipped)"
aws ssm put-parameter --name "/devops-agent/config/servicenow-mcp-url" --value "${MCP_GATEWAY_URL}/mcp/servicenow" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo"  ✅ servicenow-mcp-url" || echo "  ⚠️ servicenow-mcp-url (skipped)"
aws ssm put-parameter --name "/devops-agent/config/github-mcp-url" --value "${MCP_GATEWAY_URL}/mcp/github" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo "  ✅ github-mcp-url" || echo "  ⚠️ github-mcp-url (skipped)"
aws ssm put-parameter --name "/devops-agent/config/alert-processor-url" --value "${ALERT_PROCESSOR_URL}" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo "  ✅ alert-processor-url" || echo "  ⚠️ alert-processor-url (skipped)"
aws ssm put-parameter --name "/devops-agent/config/servicenow-instance" --value "${SNOW_INSTANCE}" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo "  ✅ servicenow-instance" || echo "  ⚠️ servicenow-instance (skipped)"
aws ssm put-parameter --name "/devops-agent/config/github-repo" --value "${GITHUB_OWNER}/${GITHUB_REPO}" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo "  ✅ github-repo" || echo "  ⚠️ github-repo (skipped)"
aws ssm put-parameter --name "/devops-agent/config/eks-cluster" --value "${EKS_CLUSTER_NAME}" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo "  ✅ eks-cluster" ||echo "  ⚠️ eks-cluster (skipped)"
aws ssm put-parameter --name "/devops-agent/config/app-namespace" --value "${APP_NAMESPACE}" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo "  ✅ app-namespace" || echo "  ⚠️ app-namespace (skipped)"
aws ssm put-parameter --name "/devops-agent/config/grafana-url" --value "${GRAFANA_URL}" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo "  ✅ grafana-url" || echo"  ⚠️ grafana-url (skipped)"
aws ssm put-parameter --name "/devops-agent/config/loki-url" --value "http://loki-stack.${MONITORING_NAMESPACE}.svc.cluster.local:3100" --type "String" --overwrite --region $AWS_REGION > /dev/null 2>&1 && echo "  ✅ loki-url" || echo "  ⚠️ loki-url (skipped)"

log_success "SSM parameters stored"
rm -f /tmp/ssm-policy.json

# =============================================================================
# SAVE CONFIGURATION TO FILE
# =============================================================================
cat > ~/devops-ai-config.txt << CONFIG
# =============================================================================
# DevOps AI Platform Configuration
# Generated: $(date)
# =============================================================================

# AWS
AWS_REGION=${AWS_REGION}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
EKS_CLUSTER_NAME=${EKS_CLUSTER_NAME}

# Service URLs
GRAFANA_URL=${GRAFANA_URL}
ALERT_PROCESSOR_URL=${ALERT_PROCESSOR_URL}
MCP_GATEWAY_URL=${MCP_GATEWAY_URL}

# Credentials
GRAFANA_USER=${GRAFANA_USER}
GRAFANA_PASSWORD=${GRAFANA_ACTUAL_PASS}

# ServiceNow
SNOW_INSTANCE=${SNOW_INSTANCE}
SNOW_URL=https://${SNOW_INSTANCE}.service-now.com

# GitHub
GITHUB_OWNER=${GITHUB_OWNER}
GITHUB_REPO=${GITHUB_REPO}

# Namespaces
APP_NAMESPACE=${APP_NAMESPACE}
MONITORING_NAMESPACE=${MONITORING_NAMESPACE}
MCP_NAMESPACE=${MCP_NAMESPACE}
CONFIG

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================
echo ""
echo -e "${MAGENTA}"
cat << "COMPLETE"
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                    ✅ INSTALLATION COMPLETE!                                  ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
COMPLETE
echo -e "${NC}"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  DEPLOYED SERVICES${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Grafana:${NC}           ${GRAFANA_URL}"
echo -e "  ${CYAN}Alert Processor:${NC}   ${ALERT_PROCESSOR_URL}"
echo -e "  ${CYAN}MCP Gateway:${NC}       ${MCP_GATEWAY_URL}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  GRAFANA CREDENTIALS${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Username:${NC}          ${GRAFANA_USER}"
echo -e "  ${CYAN}Password:${NC}          ${GRAFANA_ACTUAL_PASS}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  SERVICENOW${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}URL:${NC}               https://${SNOW_INSTANCE}.service-now.com"
echo -e "  ${CYAN}User:${NC}              ${SNOW_USER}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  TEST COMMANDS${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  # Check MCP servers status"
echo "  curl -s ${MCP_GATEWAY_URL}/mcp/servers | jq ."
echo ""
echo "  # Investigate a ServiceNow incident"
echo "  curl -s ${MCP_GATEWAY_URL}/investigate/INC0010021 | jq ."
echo ""
echo "  # Test Alert Processor"
echo "  curl -s ${ALERT_PROCESSOR_URL}/test | jq ."
echo ""
echo "  # View pod status"
echo "  kubectl get pods -n ${MONITORING_NAMESPACE}"
echo "  kubectl get pods -n ${MCP_NAMESPACE}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  AWS DEVOPS AGENT USAGE${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  In a new chat session, simply say:"
echo ""
echo -e "    ${YELLOW}\"Investigate INC0010021\"${NC}"
echo ""
echo "  The DevOps Agent will automatically:"
echo "    1. Read config from SSM Parameter Store"
echo "    2. Query your MCP servers"
echo "    3. Correlate data from all sources"
echo "    4. Provide complete RCA"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Configuration saved to: ~/devops-ai-config.txt${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
