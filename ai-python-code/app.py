
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

if not namespace or not app_name or not config_path:
    raise ValueError("Missing NAMESPACE, APP_NAME, or KUBECONFIG_PATH in .env")

config.load_kube_config(config_file=config_path)
app = Flask(__name__)

def extract_recent_errors(namespace, keywords=["ERROR", "Exception", "Traceback"], count=2):
    v1 = client.CoreV1Api()
    pods = v1.list_namespaced_pod(namespace)
    error_lines = []
    for pod in pods.items:
        try:
            raw_log = v1.read_namespaced_pod_log(pod.metadata.name, namespace)
            filtered = [line for line in raw_log.splitlines() if any(k in line for k in keywords)]
            error_lines.extend(filtered)
        except Exception as e:
            error_lines.append(f"[ERROR] Failed to read logs from {pod.metadata.name}: {str(e)}")
    return error_lines[-count:] if error_lines else ["No recent errors found."]

def extract_pod_details(namespace):
    v1 = client.CoreV1Api()
    pods = v1.list_namespaced_pod(namespace)
    pod_info = []
    for pod in pods.items:
        pod_info.append({
            "name": pod.metadata.name,
            "status": pod.status.phase,
            "restarts": sum([cs.restart_count for cs in pod.status.container_statuses or []])
        })
    return pod_info

def generate_rca(error_lines, repo_code):
    llm = AzureChatOpenAI(
        deployment_name=os.getenv("AZURE_GPT_DEPLOYMENT"),
        azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
        openai_api_key=os.getenv("AZURE_OPENAI_API_KEY"),
        openai_api_version=os.getenv("AZURE_GPT_API_VERSION")
    )
    prompt = (
        "You are an SRE assistant. Based on the following error messages from Kubernetes pod logs "
        "and the application source code, identify the root cause and explain whether the issue is code-related. "
        "If it is, specify the file name and location. If it's configuration-related, highlight that instead:\n\n"
        f"Errors:\n{chr(10).join(error_lines)}\n\n"
        f"Code:\n{repo_code}"
    )
    return llm.invoke([HumanMessage(content=prompt)]).content

@app.route('/fd_eks/')
def dashboard():
    try:
        error_lines = extract_recent_errors(namespace)
        pod_info = extract_pod_details(namespace)
        repo_code, sources = retrieve_relevant_code(error_lines)
        rca = generate_rca(error_lines, repo_code)

        return render_template_string("""
        <!DOCTYPE html>
        <html>
        <head>
            <title>EKS AI Dashboard</title>
            <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
        </head>
        <body class="bg-light">
        <div class="container py-4">
            <h1 class="mb-4 text-primary">🚀 EKS AI Dashboard</h1>

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
                            <tr>
                                <td>{{ pod.name }}</td>
                                <td>{{ pod.status }}</td>
                                <td>{{ pod.restarts }}</td>
                            </tr>
                        {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="card mb-3">
                <div class="card-header bg-danger text-white">Recent Errors</div>
                <div class="card-body">
                    <ul>{% for line in errors %}<li>{{ line }}</li>{% endfor %}</ul>
                </div>
            </div>

            <div class="card mb-3">
                <div class="card-header bg-warning text-dark">Source Files Referenced</div>
                <div class="card-body">
                    <ul>{% for src in sources %}<li>{{ src }}</li>{% endfor %}</ul>
                </div>
            </div>

            <div class="card mb-3">
                <div class="card-header bg-success text-white">Root Cause Analysis</div>
                <div class="card-body">
                    <pre>{{ rca }}</pre>
                </div>
            </div>
        </div>
        </body>
        </html>
        """, app_name=app_name, namespace=namespace, errors=error_lines, sources=sources, rca=rca, pod_info=pod_info)

    except Exception as e:
        return render_template_string("""
        <h2>Application Name: {{ app_name }}</h2>
        <h3>Error</h3>
        <p>❌ Internal Error</p>
        <pre>{{ error }}</pre>
        """, app_name=app_name, error=str(e))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5004, debug=False, use_reloader=False)
