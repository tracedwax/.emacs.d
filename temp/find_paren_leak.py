#!/usr/bin/env python3
"""Find where paren depth changes at defun boundaries in config.el.
Simple parser: tracks depth, handles strings and ;-comments."""

import re, sys

def parse_depth(filepath):
    with open(filepath) as f:
        lines = f.readlines()
    
    depth = 0
    in_string = False
    escape_next = False
    
    defun_depths = []
    
    for i, line in enumerate(lines, 1):
        line_start_depth = depth
        
        # Check if this is a defun line
        stripped = line.lstrip()
        if stripped.startswith('(defun '):
            defun_name = stripped.split()[1] if len(stripped.split()) > 1 else "?"
            defun_depths.append((i, depth, defun_name))
        
        j = 0
        while j < len(line):
            c = line[j]
            
            if escape_next:
                escape_next = False
                j += 1
                continue
            
            if c == '\\':
                escape_next = True
                j += 1
                continue
                
            if in_string:
                if c == '"':
                    in_string = False
                j += 1
                continue
            
            # Not in string
            if c == ';':  # comment - skip rest of line
                break
            if c == '"':
                in_string = True
                j += 1
                continue
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            j += 1
    
    # Print only defuns with non-zero depth (meaning prior forms leaked)
    prev_depth = 0
    for line_num, d, name in defun_depths:
        if d != prev_depth:
            print(f"line {line_num}: depth {d} (delta {d - prev_depth:+d}) -> (defun {name}")
        prev_depth = d  # Don't actually track — just show all non-1 depths
    
    # Actually just show all
    print("\n--- All defun boundaries ---")
    for line_num, d, name in defun_depths:
        if d > 1:  # depth 1 means inside use-package which is expected
            print(f"  *** line {line_num}: depth {d} -> (defun {name}")

parse_depth(sys.argv[1])
