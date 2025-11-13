from flask import Flask, jsonify
from db import get_db_time

app = Flask(__name__)

@app.get("/health")
def health():
    return jsonify(status="ok")

@app.get("/")
def index():
    db_time = get_db_time()
    return jsonify(message="Boilerplate of Flask App", db_time=db_time)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)