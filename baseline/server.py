import time
import os
import sys
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/completion', methods=['POST'])
def completion():
    data = request.get_json(silent=True) or {}
    prompt = data.get('prompt', 'Hi')
    
    # Read configuration from the ConfigMap (student task to wire this up)
    model_name = os.environ.get('MODEL_NAME', 'unknown-model')
    ctx_size = os.environ.get('CTX_SIZE', 'unknown-ctx')
    
    # Log the configuration to stdout for kubectl logs verification
    print(f"[INFO] Using model: {model_name} | Context size: {ctx_size}", file=sys.stdout)
    sys.stdout.flush()

    # Simulate LLM inference by burning CPU for 1-2 seconds
    # This will trigger the HPA (CPU > 50%) when load tested
    # and use some memory
    end_time = time.time() + 1.5
    dummy_memory = []
    while time.time() < end_time:
        _ = [x**2 for x in range(10000)]
        dummy_memory.append(' ' * 1024 * 1024) # Allocate memory to simulate real model usage
        
    return jsonify({"response": f"Mock LLM response to: {prompt}"})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
