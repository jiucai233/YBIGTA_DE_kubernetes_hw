import os
import urllib.request

def main():
    # Change context to the directory of this script (baseline/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if script_dir:
        os.chdir(script_dir)
    
    model_url = "https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_0.gguf"
    mirror_url = "https://hf-mirror.com/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_0.gguf"
    file_name = "mock_model.gguf"
    
    if not os.path.exists(file_name):
        print("Downloading a mock ~350MB GGUF model for testing bloat...")
        urls = [
            ("primary HuggingFace server", model_url),
            ("huggingface mirror (hf-mirror.com)", mirror_url)
        ]
        
        success = False
        for name, url in urls:
            print(f"Attempting download via {name}...")
            try:
                urllib.request.urlretrieve(url, file_name)
                print(f"Download successful from {name}.")
                success = True
                break
            except Exception as e:
                print(f"Failed to download from {name}: {e}")
                
        if not success:
            print("All download methods failed. Please check your network or ISP firewall.")
    else:
        print(f"Model {file_name} already exists in baseline/.")

if __name__ == "__main__":
    main()
