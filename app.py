from flask import Flask, request, Response, send_from_directory
from werkzeug.utils import secure_filename
import os
import psycopg2
from dotenv import load_dotenv
from storage import upload_file, get_file

load_dotenv()

def get_db_connection():
    """Open a new PostgreSQL connection from the DATABASE_URL env var.

    Returns:
        psycopg2 connection: a fresh connection the caller is responsible for closing.
    """
    return psycopg2.connect(os.environ["DATABASE_URL"])

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"]=int(os.environ["MAX_UPLOAD_SIZE"])

@app.route("/health")
def health():
    """Liveness probe. Does not touch the database or object storage.

    Returns:
        dict: {"status": "ok"} (HTTP 200).
    """
    return {"status": "ok"}

@app.route("/items", methods=["POST"])
def set_items():
    """Handle an image upload: store the file in MinIO and its metadata in Postgres.

    Reads a multipart form with fields `image` (file), `title` and `target_url`.
    The file bytes are uploaded to the S3 bucket (object key = sanitized filename);
    a metadata row is inserted into the `items` table.

    Returns:
        dict | tuple: {"error": ...}, 400 if a field is missing; otherwise
        {"status": "uploaded", "id": <new id>, "filename": <safe name>} (HTTP 200).
    """
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
    data = file.read()
    upload_file(body=data, bucket_name=os.environ["S3_BUCKET"], object_key=safe_name, content_type=file.content_type)
    file_size = len(data)
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
    """List all items, newest first, from the database.

    Returns:
        dict: {"items": [{id, filename, title, target_url, size_bytes, created_at}, ...]}.
    """
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
    """Serve the single-page web UI (static/index.html).

    Returns:
        Response: the index.html file.
    """
    return send_from_directory("static", "index.html")

@app.route("/uploads/<filename>")
def serve_upload(filename):
    """Stream an uploaded image back from MinIO.

    Args:
        filename (str): the object key to fetch from the bucket.

    Returns:
        Response: the image bytes with their content-type (HTTP 200), or
        {"error": ...}, 404 if the object does not exist.
    """
    result = get_file(bucket_name=os.environ["S3_BUCKET"], object_key=filename)
    if result is None:
        return {"error": "content file not found"}, 404
    body, contentType = result
    return Response(response=body, mimetype=contentType)