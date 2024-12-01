from pathlib import Path
import shutil
import subprocess
import sys
import os

def configure_apt_sources():
    """Configure APT sources to use an Artifactory repository if provided."""
    artifactory_url = os.getenv("ARTIFACTORY_URL")
    sources_list_path = Path("/etc/apt/sources.list")

    if artifactory_url:
        print(f"Configuring APT to use Artifactory repository: {artifactory_url}")
        sources_content = f"""\
        deb [trusted=yes] {artifactory_url}/ubuntu focal main restricted universe multiverse
        deb [trusted=yes] {artifactory_url}/ubuntu focal-updates main restricted universe multiverse
        deb [trusted=yes] {artifactory_url}/ubuntu focal-security main restricted universe multiverse
        """
        # Update the sources.list file
        sources_list_path.write_text(sources_content)
        # Update the package index
        subprocess.run(["apt-get", "update"], check=True)
    else:
        print("No ARTIFACTORY_URL provided. Using default APT repositories.")

def run_main_app():
    print("Startup Script for Kubernetes Pod Starting...")

    # Read environment variables
    application_path_str = os.getenv("APPLICATION_PATH", "")
    mount_path_base_str = os.getenv("MOUNT_PATH_BASE", "")
    
    if not application_path_str:
        print(f"ERROR: APPLICATION_PATH={application_path_str} is empty. Can't start app.")
        sys.exit(0)
    
    application_path = Path(application_path_str)  # e.g., /src/out/myapp.dll
    mount_path_base = Path(mount_path_base_str)    # e.g., /volume/
    
    if not application_path.exists():
        print(f"ERROR: APPLICATION_PATH={application_path} doesn't exist")
        sys.exit(1)

    if not mount_path_base_str or not mount_path_base.exists():
        print(f"WARN: Mount path MOUNT_PATH_BASE={mount_path_base} doesn't exist. Starting app regularly.")
        run_application(application_path)
        return

    application_dir = application_path.parent
    application_base_dir = Path("/") / application_path.parts[1]  # Extract first-level directory

    print("Provided Variables:")
    print(f"  Application Path: {application_path}")
    print(f"  Application Directory: {application_dir}")
    print(f"  Mount Directory (Base): {mount_path_base}")

    # Ensure the application path exists
    if not application_path.is_file():
        print(f"ERROR: The application path '{application_path}' does not exist in the pod.")
        sys.exit(1)

    # Check if mount path exists and handle accordingly
    if mount_path_base.is_dir():
        print(f"Mount directory '{mount_path_base}' exists. Checking its contents...")

        if not any(mount_path_base.iterdir()):  # Mount directory is empty
            print(f"Mount directory is empty. Copying application files from '{application_base_dir}' to '{mount_path_base}'...")
            shutil.copytree(application_base_dir, mount_path_base / application_base_dir.relative_to("/"), dirs_exist_ok=True)
            print("Copy complete. Launching application from the mount directory.")
            run_application(mount_path_base / application_path.relative_to("/"))

        elif (mount_path_base / application_path.relative_to("/")).is_file():  # App exists in mount
            print(f"Application already exists in the mount directory ('{mount_path_base / application_path.relative_to('/')}'). Launching from there...")
            run_application(mount_path_base / application_path.relative_to("/"))

        else:  # Mount is not empty but does not contain the app
            print("Mount directory is not empty but does not contain the application. Running application from its regular location in the pod.")
            run_application(application_path)

    else:  # Mount path does not exist
        print(f"Mount directory '{mount_path_base}' does not exist. Running application from its regular location in the pod.")
        run_application(application_path)

def run_application(path):
    """Executes the application."""
    print(f"Running application from: {path}")
    application_dir = path.parent
    os.chdir(application_dir)
    subprocess.run(["dotnet", str(path)], check=True)


def main():
    configure_apt_sources()
    run_main_app()

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)
