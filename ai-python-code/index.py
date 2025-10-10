
import os
import shutil
import subprocess
import requests
from dotenv import load_dotenv
from datetime import datetime
from langchain_community.vectorstores import FAISS
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.docstore.document import Document
from langchain.embeddings.base import Embeddings

load_dotenv()

REPO_URL = os.getenv("REPO_URL")
REPO_PATH = os.getenv("REPO_PATH")
DB_PATH = "./vector_db"

class AzureEmbedding(Embeddings):
    def __init__(self):
        self.endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        self.deployment = os.getenv("AZURE_EMBEDDING_DEPLOYMENT")
        self.api_version = os.getenv("AZURE_EMBEDDING_API_VERSION")
        self.api_key = os.getenv("AZURE_OPENAI_API_KEY")

    def embed_documents(self, texts: list) -> list:
        return self._embed(texts)

    def embed_query(self, text: str) -> list:
        return self._embed([text])[0]

    def _embed(self, texts: list) -> list:
        url = f"{self.endpoint}openai/deployments/{self.deployment}/embeddings?api-version={self.api_version}"
        headers = {
            "Content-Type": "application/json",
            "api-key": self.api_key
        }
        payload = {"input": texts}
        response = requests.post(url, headers=headers, json=payload)
        if response.status_code == 200:
            return [r["embedding"] for r in response.json()["data"]]
        else:
            raise Exception(f"Embedding failed: {response.status_code} - {response.text}")

def validate_env():
    required_vars = [
        "AZURE_OPENAI_API_KEY",
        "AZURE_OPENAI_ENDPOINT",
        "AZURE_EMBEDDING_DEPLOYMENT",
        "AZURE_EMBEDDING_API_VERSION",
        "REPO_URL",
        "REPO_PATH"
    ]
    missing = [var for var in required_vars if not os.getenv(var)]
    if missing:
        print(f"❌ Missing variables: {', '.join(missing)}")
        return False
    return True

def clone_repo():
    if os.path.exists(REPO_PATH):
        shutil.rmtree(REPO_PATH)
    subprocess.run(["git", "clone", REPO_URL], check=True)

def load_code_files(repo_path):
    docs = []
    for root, _, files in os.walk(repo_path):
        for file in files:
            if file.endswith((".java", ".py", ".yaml", ".yml", ".xml", ".properties", "Dockerfile", "Jenkinsfile")):
                full_path = os.path.join(root, file)
                try:
                    with open(full_path, "r", encoding="utf-8") as f:
                        content = f.read()
                except UnicodeDecodeError:
                    with open(full_path, "r", encoding="latin-1") as f:
                        content = f.read()
                docs.append(Document(page_content=content, metadata={"source": full_path}))
    return docs

def index_repo():
    print(f"🕒 Indexing started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    if not validate_env():
        print("❌ Aborting due to environment misconfiguration.")
        return

    clone_repo()
    raw_docs = load_code_files(REPO_PATH)
    splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
    chunks = splitter.split_documents(raw_docs)

    if not chunks:
        print("❌ No valid code chunks found.")
        return

    embeddings = AzureEmbedding()
    os.makedirs(DB_PATH, exist_ok=True)
    db = FAISS.from_documents(chunks, embeddings)
    db.save_local(DB_PATH)
    print("✅ Indexing complete.")

if __name__ == "__main__":
    index_repo()
