
import os
from flask import Flask, render_template_string
from kubernetes import client, config
from dotenv import load_dotenv
from langchain_openai import AzureChatOpenAI
from langchain.schema import HumanMessage
from retrieve_chunks import retrieve_relevant_code

load_dotenv()

namespace = os.getenv("NAMESPACE")
app_name = os.getenv("APP_NAME")
config_path = os.getenv("KUBECONFIG_PATH")

config.load_kube_config(config_file=config_path)
app = Flask(__name__)

def extract_last_200_lines(namespace):
    v1 = client.CoreV1Api()
    pods = v1.list_namespaced_pod(namespace)
    all_lines = []
    for pod in pods.items:
        try:
            raw_log = v1.read_namespaced_pod_log(pod.metadata.name, namespace)
            lines = raw_log.splitlines()
            tagged = [f"[{pod.metadata.name}] {line}" for line in lines[-200:]]
            all_lines.extend(tagged)
        except Exception as e:
            all_lines.append(f"[ERROR] Failed to read logs from {pod.metadata.name}: {str(e)}")
    return all_lines, pods.items

def extract_last_error_line(log_lines, keywords=["ERROR", "Exception", "Traceback"]):
    for line in reversed(log_lines):
        if any(k in line for k in keywords):
            return line
    return "No recent error found."

def extract_pod_details(namespace):
    v1 = client.CoreV1Api()
    pods = v1.list_namespaced_pod(namespace)
    return [{
        "name": pod.metadata.name,
        "status": pod.status.phase,
        "restarts": sum([cs.restart_count for cs in pod.status.container_statuses or []])
    } for pod in pods.items]

def extract_pod_descriptions(pods, namespace):
    v1 = client.CoreV1Api()
    descriptions = []
    for pod in pods:
        try:
            desc = v1.read_namespaced_pod(name=pod.metadata.name, namespace=namespace, pretty=True)
            descriptions.append(f"=== Pod: {pod.metadata.name} ===\n{desc}")
        except Exception as e:
            descriptions.append(f"[ERROR] Failed to describe pod {pod.metadata.name}: {str(e)}")
    return descriptions

def generate_single_rca(last_error, full_log, pod_descriptions, code_snippets):
    llm = AzureChatOpenAI(
        deployment_name=os.getenv("AZURE_GPT_DEPLOYMENT"),
        azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
        openai_api_key=os.getenv("AZURE_OPENAI_API_KEY"),
        openai_api_version=os.getenv("AZURE_GPT_API_VERSION")
    )
    prompt = f"""You are an expert SRE assistant.

Analyze the following Kubernetes pod logs, pod descriptions, and matched source lines. Focus only on the **last error** shown below.

=== RCA Report ===
📍 Issue Type: [Code / Config / Infra]
📄 File & Line: [Exact file path and line number]
🧠 Root Cause Summary: [1–2 sentence summary of the issue]
🛠️ Suggested Fix: [Clear fix with rationale]
⚠️ Severity: [Low / Medium / High]
✅ Confidence: [Low / Medium / High]
===================

Last Error:
{last_error}

Full Logs:
{chr(10).join(full_log)}

Pod Descriptions:
{chr(10).join(pod_descriptions)}

Matched Source Lines:
{code_snippets}
"""
    return llm.invoke([HumanMessage(content=prompt)]).content

@app.route('/fd_eks/')
def dashboard():
    try:
        log_lines, pods = extract_last_200_lines(namespace)
        last_error = extract_last_error_line(log_lines)
        pod_info = extract_pod_details(namespace)
        pod_descriptions = extract_pod_descriptions(pods, namespace)
        code_snippets, sources = retrieve_relevant_code([last_error])
        rca = generate_single_rca(last_error, log_lines, pod_descriptions, code_snippets)

        return render_template_string("""
        <!DOCTYPE html>
        <html>
        <head>
            <title>EKS AI Dashboard</title>
            <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
            <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
        </head>
        <body class="bg-light">
        <div class="container py-4">
            <h1 class="mb-4 text-primary">🚀 EKS AI Dashboard (Agentic)</h1>

            <div class="card mb-3">
                <div class="card-header bg-info text-white">Application Info</div>
                <div class="card-body">
                    <p><strong>Name:</strong> {{ app_name }}</p>
                    <p><strong>Namespace:</strong> {{ namespace }}</p>
                </div>
            </div>

            <div class="card mb-3">
                <div class="card-header bg-secondary text-white">Pod Details</div>
                <div class="card-body">
                    <table class="table table-bordered">
                        <thead><tr><th>Name</th><th>Status</th><th>Restarts</th></tr></thead>
                        <tbody>
                        {% for pod in pod_info %}
                            <tr><td>{{ pod.name }}</td><td>{{ pod.status }}</td><td>{{ pod.restarts }}</td></tr>
                        {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="card mb-3">
                <div class="card-header bg-danger text-white">Last Error</div>
                <div class="card-body"><pre>{{ last_error }}</pre></div>
            </div>

            <div class="card mb-3">
                <div class="card-header bg-success text-white">Root Cause Analysis</div>
                <div class="card-body">
                    <pre style="white-space: pre-wrap; font-family: 'Courier New', monospace; background-color: #f8f9fa; padding: 1em; border-radius: 5px;">{{ rca }}</pre>
                </div>
            </div>

            <div class="card mb-3">
                <div class="card-header bg-warning text-dark">
                    <button class="btn btn-sm btn-outline-dark" type="button" data-bs-toggle="collapse" data-bs-target="#sourceFiles" aria-expanded="false" aria-controls="sourceFiles">
                        🔍 Toggle Source Files Referenced
                    </button>
                </div>
                <div id="sourceFiles" class="collapse">
                    <div class="card-body">
                        <ul>{% for src in sources %}<li>{{ src }}</li>{% endfor %}</ul>
                    </div>
                </div>
            </div>
        </div>
        </body>
        </html>
        """, app_name=app_name, namespace=namespace, pod_info=pod_info, last_error=last_error, rca=rca, sources=sources)

    except Exception as e:
        return render_template_string("""
        <h2>Application Name: {{ app_name }}</h2>
        <h3>Error</h3>
        <p>❌ Internal Error</p>
        <pre>{{ error }}</pre>
        """, app_name=app_name, error=str(e))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5004, debug=False, use_reloader=False)
