from flask import Flask, request
from werkzeug.utils import secure_filename
import os
import psycopg2

def get_db_connection():
    return psycopg2.connect(os.environ["DATABASE_URL"])

app = Flask(__name__)

@app.route("/health")
def health():
    return {"status": "ok"}

@app.route("/upload", methods=["POST"])
def upload():
    file = request.files.get("image")
    if not file:
        return {"error": "no file provided"}, 400
    safe_name = secure_filename(file.filename)
    if not safe_name:
        return {"error": "no valid file name provided"}, 400
    chemin = os.path.join(os.environ["UPLOAD_DIR"], safe_name)
    file.save(chemin)
    file_size = os.path.getsize(chemin)
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO images (filename, size_bytes) VALUES (%s,%s) RETURNING id;", (safe_name, file_size))
            new_id = cur.fetchone()[0]
        conn.commit()
    finally:
        conn.close()
    return {"status": "uploaded", "id": new_id, "filename": safe_name}
