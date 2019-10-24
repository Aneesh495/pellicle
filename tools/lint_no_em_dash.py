#!/usr/bin/env python3
"""
Pellicle Typography Invariant Linter
Asserts that no Unicode em dashes (U+2014) or en dashes (U+2013) exist
in any source file, comment, documentation, or configuration.
"""

import sys
import os

FORBIDDEN_CHARS = {
    '\u2014': 'Em dash (U+2014)',
    '\u2013': 'En dash (U+2013)',
}

EXCLUDED_DIRS = {'.git', 'build', '__pycache__', '.pytest_cache'}
EXCLUDED_EXTS = {'.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.a', '.o', '.so', '.dylib', '.bin'}

def scan_file(filepath):
    violations = []
    try:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            for line_no, line in enumerate(f, start=1):
                for char, desc in FORBIDDEN_CHARS.items():
                    if char in line:
                        col = line.index(char) + 1
                        violations.append((filepath, line_no, col, desc, line.strip()))
    except Exception as e:
        pass
    return violations

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    all_violations = []

    for dirpath, dirnames, filenames in os.walk(root_dir):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDED_DIRS]
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            if ext in EXCLUDED_EXTS:
                continue
            fpath = os.path.join(dirpath, fname)
            violations = scan_file(fpath)
            all_violations.extend(violations)

    if all_violations:
        print(f"FAILED: Found {len(all_violations)} typography invariant violation(s):")
        for v in all_violations:
            print(f"  {v[0]}:{v[1]}:{v[2]}: {v[3]} -> {v[4]}")
        sys.exit(1)
    else:
        print("OK: Zero em dashes or en dashes detected across all files.")
        sys.exit(0)

if __name__ == '__main__':
    main()
