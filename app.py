from flask import Flask, request, send_from_directory
from werkzeug.utils import secure_filename
import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

def get_db_connection():
    return psycopg2.connect(os.environ["DATABASE_URL"])

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"]=int(os.environ["MAX_UPLOAD_SIZE"])

@app.route("/health")
def health():
    return {"status": "ok"}

@app.route("/items", methods=["POST"])
def set_items():
    file = request.files.get("image")
    if not file:
        return {"error": "no file provided"}, 400
    safe_name = secure_filename(file.filename)
    if not safe_name:
        return {"error": "no valid file name provided"}, 400
    title = request.form.get("title")
    if not title:
        return {"error": "no title provided"}, 400
    target_url = request.form.get("target_url")
    if not target_url:
        return {"error": "no url provided"}, 400   
    chemin = os.path.join(os.environ["UPLOAD_DIR"], safe_name)
    file.save(chemin)
    file_size = os.path.getsize(chemin)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO items (filename, title, target_url, size_bytes) VALUES (%s,%s,%s,%s) RETURNING id;", (safe_name, title, target_url, file_size))
            new_id = cur.fetchone()[0]
        conn.commit()
    finally:
        conn.close()
    return {"status": "uploaded", "id": new_id, "filename": safe_name}

@app.route("/items", methods=["GET"])
def get_items():
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, filename, title, target_url, size_bytes, created_at FROM items ORDER BY created_at DESC;")
            rows = cur.fetchall()
        items =  [{"id": r[0], "filename": r[1], "title": r[2], "target_url": r[3], "size_bytes": r[4], "created_at": r[5]} for r in rows]
    finally:
        conn.close()
    return {"items": items}

@app.route("/")
def index():
    return send_from_directory("static", "index.html")

@app.route("/uploads/<filename>")
def serve_upload(filename):
    return send_from_directory(os.environ["UPLOAD_DIR"], filename)