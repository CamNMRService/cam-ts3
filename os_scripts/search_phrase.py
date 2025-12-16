#!/usr/bin/env python3
import os
import sys
import csv
import multiprocessing
from functools import partial
from tqdm import tqdm

MAX_LINE_LEN = 256


def get_phrase():
    while True:
        try:
            n = int(input("How many words are in the sequence? "))
            if n <= 0:
                print("Enter a positive number.")
                continue
            break
        except ValueError:
            print("Please enter a valid number.")

    words = []
    for i in range(n):
        w = input(f"Enter word #{i+1}: ").strip()
        words.append(w)

    phrase = " ".join(words)
    print(f"\nSearching for phrase: '{phrase}'\n")
    return phrase


def is_binary_file(fullpath):
    """Returns True if file appears to be binary."""
    try:
        with open(fullpath, "rb") as f:
            chunk = f.read(1024)
            if b"\x00" in chunk:
                return True
        return False
    except Exception:
        return True  # treat unreadable files as binary


def scan_file(phrase, fullpath):
    """Return list of matches: (path, lineno, text)."""
    phrase_lower = phrase.lower()
    results = []

    # Skip binary files
    if is_binary_file(fullpath):
        return results

    try:
        with open(fullpath, "r", errors="ignore") as f:
            for lineno, line in enumerate(f, start=1):
                if phrase_lower in line.lower():
                    text = line.strip().replace("\n", " ")
                    if len(text) > MAX_LINE_LEN:
                        text = text[:MAX_LINE_LEN] + "…"
                    results.append((fullpath, lineno, text))
    except Exception:
        return results

    return results


def collect_files(root):
    """Return a list of all file paths in the directory tree."""
    file_list = []
    for dirpath, _, filenames in os.walk(root):
        for filename in filenames:
            fullpath = os.path.join(dirpath, filename)
            file_list.append(fullpath)
    return file_list


def write_csv(matches):
    csv_filename = "search_results.csv"
    with open(csv_filename, "w", newline="") as csvfile:
        writer = csv.writer(
            csvfile,
            quoting=csv.QUOTE_ALL,
            escapechar='\\',
        )
        writer.writerow(["file_path", "line_number", "line_text"])
        for row in matches:
            writer.writerow(row)

    print(f"\nResults written to: {csv_filename}")


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 search_phrase.py /path/to/search")
        sys.exit(1)

    root = sys.argv[1]
    phrase = get_phrase()

    print("Collecting files…")
    file_list = collect_files(root)
    print(f"Scanning {len(file_list)} files in parallel…")

    matches = []

    # Prepare function with phrase bound
    worker = partial(scan_file, phrase)

    # Use CPU cores
    with multiprocessing.Pool() as pool:
        for result in tqdm(pool.imap_unordered(worker, file_list),
                           total=len(file_list),
                           desc="Searching",
                           unit="file"):
            if result:
                matches.extend(result)

    print(f"\nFound {len(matches)} matches total.")
    write_csv(matches)


if __name__ == "__main__":
    main()

