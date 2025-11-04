import os
from langchain_community.vectorstores import FAISS
from index import AzureEmbedding
from dotenv import load_dotenv

load_dotenv()
DB_PATH = "./vector_db"
REPO_ROOT = os.getenv("REPO_ROOT", ".")

def scan_repo_for_candidates(root, extensions=(".java", ".properties")):
    candidates = []
    for dirpath, _, files in os.walk(root):
        for file in files:
            if file.endswith(extensions):
                candidates.append(os.path.join(dirpath, file))
    return candidates

def retrieve_relevant_code(error_lines, top_k=3):
    # Enhance query with semantic anchors
    query = "\n".join([
        f"[ERROR] {line}" if "404" in line or "Exception" in line else line
        for line in error_lines
    ])

    embeddings = AzureEmbedding()
    db = FAISS.load_local(DB_PATH, embeddings, allow_dangerous_deserialization=True)
    results = db.similarity_search(query, k=top_k)

    code_snippets = []
    sources = set()

    # Filter results to prioritize controller/config files
    for doc in results:
        src = doc.metadata["source"]
        if any(ext in src for ext in [".java", ".properties"]):
            sources.add(src)
            code_snippets.append(f"// Source: {src}\n{doc.page_content}")

    # Fallback: scan repo for line-level matches
    keywords = [line.split(":")[0] for line in error_lines if ":" in line]
    candidates = scan_repo_for_candidates(REPO_ROOT)

    for path in candidates:
        if path not in sources:
            try:
                with open(path, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                    matched = []
                    for i, line in enumerate(lines):
                        if any(k in line for k in keywords):
                            matched.append(f"{path}:{i+1}: {line.strip()}")
                    if matched:
                        code_snippets.append(f"// Source (fallback): {path}\n" + "\n".join(matched))
                        sources.add(path)
            except Exception as e:
                print(f"⚠️ Failed to scan fallback file {path}: {e}")

    return "\n\n".join(code_snippets), list(sources)
