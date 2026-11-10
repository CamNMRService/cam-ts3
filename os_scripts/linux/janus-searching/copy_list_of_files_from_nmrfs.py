#!/usr/bin/env python3
import getpass
import os
import platform
from pathlib import Path
import subprocess
import sys
import time


def main():
    # Detect operating system
    system_os = platform.system()
    home_dir = Path.home()
    local_dir = home_dir / "autocopied-nmr-data"

    # Set OS-specific mount locations
    if system_os == "Darwin":  # macOS
        mount_dir = Path("/Volumes/NMRArchive")
    else:  # Linux / Unix
        mount_dir = Path("/media/NMRArchive")

    # Inputs
    crsid = input("Enter your CRSID - ").strip()
    password = getpass.getpass("Enter Admitto password for NMRShares - ")
    file_list_name = input("Enter filename of file list to copy - ").strip()

    file_list_path = (Path.cwd() / file_list_name).resolve()

    print(f"\nHome directory: {home_dir}")
    print(f"Directory to copy to: {local_dir}")
    print(f"Path of filelist: {file_list_path}\n")

    if not file_list_path.is_file():
        print(f"Error: File list '{file_list_path}' does not exist.")
        sys.exit(1)

    local_dir.mkdir(parents=True, exist_ok=True)

    # Server address unified across all platforms
    server_address = "nmr-fs.ch.private.cam.ac.uk/NMRArchive"

    # Mount share depending on platform
    if system_os == "Darwin":
        print("Mounting SMB share on macOS...")
        smb_url = f"smb://{crsid}:{password}@{server_address}"
        subprocess.run(["open", smb_url], check=False)
    elif system_os == "Linux":
        print("Mounting SMB share on Linux...")
        mount_dir.mkdir(parents=True, exist_ok=True)
        mount_cmd = [
            "sudo",
            "mount",
            "-t",
            "cifs",
            "-o",
            f"username={crsid},password={password}",
            f"//{server_address}",
            str(mount_dir),
        ]
        subprocess.run(mount_cmd, check=False)

    # Security: clear password variable immediately after mount attempt
    del password

    print("Waiting 10 seconds for mount to complete...")
    time.sleep(10)

    # Get year ranges
    try:
        start_year = int(input("Enter start year: ").strip())
        end_year = int(input("Enter end year: ").strip())
    except ValueError:
        print("Error: Years must be integers.")
        sys.exit(1)

    spectrometers = ["laphroiag", "lagavulin", "glenfairn", "arran", "tobermory"]

    # Loop through years, quarters, and spectrometers
    for year in range(start_year, end_year + 1):
        for qtr in range(1, 5):
            quarter = f"Q{qtr}-{year}"
            print(f"\nProcessing quarter: {quarter}")

            for spec in spectrometers:
                remote_dir = mount_dir / quarter / spec / "chemist" / "nmr"
                print(f"Checking directory: {remote_dir}")

                if remote_dir.exists():
                    print(f"Copying files from: {remote_dir}")
                    rsync_cmd = [
                        "rsync",
                        "--progress",
                        "-arvP",
                        f"--files-from={file_list_path}",
                        "./",
                        f"{local_dir}/",
                    ]
                    # Execute rsync with remote_dir as working directory
                    subprocess.run(rsync_cmd, cwd=remote_dir, check=False)
                else:
                    print(f"Directory missing, skipping: {remote_dir}")


if __name__ == "__main__":
    main()

