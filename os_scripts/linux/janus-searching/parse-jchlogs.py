import os
import re
from datetime import datetime
from pathlib import Path

def sanitize_filename(name: str) -> str:
    """Sanitize the search term to make it safe for file names across OS platforms."""
    clean = re.sub(r'[^\w\-]', '_', name)
    clean = re.sub(r'_+', '_', clean).strip('_')
    return clean or "query"

def parse_log_files():
    folder_input = input("Enter folder path: ").strip()
    pattern_input = input("Enter file pattern to match (e.g., *.txt): ").strip() or "*.txt"
    search_term_raw = input("Enter search string to filter lines: ").strip()
    search_term = search_term_raw.lower()

    target_dir = Path(folder_input)
    if not target_dir.is_dir():
        print(f"Error: Directory '{folder_input}' does not exist.")
        return

    matching_files = list(target_dir.glob(pattern_input))
    if not matching_files:
        print(f"No files matching '{pattern_input}' found in '{folder_input}'.")
        return

    full_lines = []
    first_portions = []

    PREFIX_EXACT = " Specno: "

    for file_path in matching_files:
        if not file_path.is_file():
            continue

        try:
            with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line_str = line.rstrip("\r\n")

                    # Match lines starting with " Specno: " (handles standard and non-breaking spaces)
                    if line_str.startswith(PREFIX_EXACT) or line_str.lstrip(" \xa0").startswith("Specno: "):
                        # Case-insensitive search match
                        if search_term in line_str.lower():
                            # Strip " Specno: " prefix
                            if line_str.startswith(PREFIX_EXACT):
                                stripped = line_str[len(PREFIX_EXACT):]
                            else:
                                stripped = line_str.lstrip(" \xa0")[len("Specno: "):]

                            # File 1: Full line without " Specno: "
                            full_lines.append(stripped)

                            # File 2: First portion up to the first comma
                            first_part = stripped.split(",", 1)[0]
                            first_portions.append(first_part)

        except Exception as e:
            print(f"Skipping {file_path.name} due to read error: {e}")

    # Generate timestamp in format YYYY_MM_DD_HH_MM_SS
    timestamp = datetime.now().strftime("%Y_%m_%d_%H_%M_%S")
    safe_search_tag = sanitize_filename(search_term_raw)

    out_full_path = target_dir / f"output_full_lines_{safe_search_tag}_{timestamp}.txt"
    out_first_part_path = target_dir / f"output_specno_only_{safe_search_tag}_{timestamp}.txt"

    with open(out_full_path, "w", encoding="utf-8") as f:
        f.write("\n".join(full_lines) + ("\n" if full_lines else ""))

    with open(out_first_part_path, "w", encoding="utf-8") as f:
        f.write("\n".join(first_portions) + ("\n" if first_portions else ""))

    print(f"\nProcessing complete across {len(matching_files)} file(s).")
    print(f"Total matching lines found: {len(full_lines)}")
    print(f"1. Full lines output: {out_full_path.name}")
    print(f"2. Spec numbers output: {out_first_part_path.name}")

if __name__ == "__main__":
    parse_log_files()

