import platform
import subprocess
import os
import sys
import urllib.request

def run_cmd(cmd, shell=False):
    subprocess.run(cmd, shell=shell, check=True)

def main():
    system = platform.system().lower()
    print("========================================")
    print(f"Installing dependencies for {system}...")
    print("========================================")

    if system == "darwin":
        # Mac
        try:
            run_cmd(["brew", "--version"])
        except Exception:
            print("Error: Homebrew is not installed. Please install it first from https://brew.sh/")
            sys.exit(1)
        print("Installing kubectl, k3d, and hey...")
        run_cmd(["brew", "install", "kubectl", "k3d", "hey"])
        
    elif system == "windows":
        print("Installing kubectl and k3d...")
        try:
            run_cmd(["winget", "install", "-e", "--id", "Kubernetes.kubectl"])
            run_cmd(["winget", "install", "k3d"])
        except Exception:
            print("Failed to use winget. Please install winget or install tools manually.")
            
        print("Downloading hey...")
        try:
            urllib.request.urlretrieve("https://hey-release.s3.us-east-2.amazonaws.com/hey_windows_amd64.exe", "hey.exe")
            print("hey.exe downloaded to the current directory. You can use it directly or add it to your PATH.")
        except Exception as e:
            print(f"Failed to download hey: {e}")

    else:
        # Linux / WSL
        print("1/3: Installing kubectl...")
        run_cmd("curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"", shell=True)
        run_cmd("sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl", shell=True)
        run_cmd("rm kubectl", shell=True)
        
        print("2/3: Installing k3d...")
        run_cmd("curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash", shell=True)
        
        print("3/3: Installing hey...")
        run_cmd("sudo curl -L -o /usr/local/bin/hey https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64", shell=True)
        run_cmd("sudo chmod +x /usr/local/bin/hey", shell=True)

    print("========================================")
    print("All CLI tools installed successfully!")
    print("Note: You must ensure Docker is installed and running.")
    print("========================================")

if __name__ == "__main__":
    main()
