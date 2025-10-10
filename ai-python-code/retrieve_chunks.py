from langchain_community.vectorstores import FAISS
from index import AzureEmbedding
from dotenv import load_dotenv
import os

load_dotenv()
DB_PATH = "./vector_db"

def retrieve_relevant_code(error_lines, top_k=3):
    query = "\n".join(error_lines)
    embeddings = AzureEmbedding()
    db = FAISS.load_local(DB_PATH, embeddings, allow_dangerous_deserialization=True)
    results = db.similarity_search(query, k=top_k)

    code_blocks = []
    sources = []
    for doc in results:
        sources.append(doc.metadata["source"])
        code_blocks.append(f"// Source: {doc.metadata['source']}\n{doc.page_content}")

    return "\n\n".join(code_blocks), sources
