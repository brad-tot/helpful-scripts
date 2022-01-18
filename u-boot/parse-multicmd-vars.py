#!/usr/bin/env python3
# --------------- Copyright (c) Takeoff Technical LLC 2022 -------------------
# Purpose: This script parses the u-boot environment variables and splits out
#          the ones with mulitple commands into separate lines with leading
#          spaces for readability.
# License: GPL v3
# ----------------------------------------------------------------------------

import argparse
import sys

# Read the command line inputs
parser = argparse.ArgumentParser(description="Script to parse u-boot's environment for readability.")
parser.add_argument(
    'mode',
    type=str,
    choices=['expand', 'condense'],
    help='Specifies whether to expand to multiple lines or condense to single-line for multi-cmd variables.'
)
parser.add_argument(
    'input', 
    type=str,
    help='Path to the u-boot environment file to use as input.'
)
parser.add_argument(
    "output",
    type=str,
    help='Path to the u-boot environment file to use as output.'
)
args = parser.parse_args()

# Open the files  
input_file = open(args.input, 'r')
output_file = open(args.output, 'w', newline='\n')

# Function to expand
def ExpandEnvFile():
    for input_line in input_file:
        trimmed = input_line.strip()
        if len(trimmed) <= 0 or trimmed.startswith('Environment size:'):
            output_file.write(trimmed + '\n')
            continue
        first_equals=trimmed.find('=')
        if input_line[0].isspace() or first_equals <= 0:
            sys.stderr.write('Invalid input file syntax! [%s]' % input_line)
            sys.exit(1)
        env_var = trimmed[:first_equals]
        value = trimmed[first_equals+1:]
        if ';' in value:
            indent_level=1
            output_file.write(env_var + '=' + '\n')
            parts = value.split(';')
            for part in parts:
                part = part.strip()
                if len(part) <= 0:
                    continue
                if part.startswith('then '):
                    leading_space = ' ' * (4 * (indent_level - 1))
                    output_file.write(leading_space + 'then\n')
                    part = part[len('then '):]
                elif part.startswith('else '):
                    leading_space = ' ' * (4 * (indent_level - 1))
                    output_file.write(leading_space + 'else\n')
                    part = part[len('else '):]
                elif part.startswith('do '):
                    leading_space = ' ' * (4 * (indent_level - 1))
                    output_file.write(leading_space + 'do\n')
                    part = part[len('do '):]
                elif part == 'fi' or part == 'done':
                    indent_level = indent_level - 1
                leading_space = ' ' * (4 * indent_level)
                output_file.write(leading_space + part + ';\n')
                if part.startswith('if ') or part.startswith('for '):
                    indent_level = indent_level + 1 
        else:
            output_file.write(env_var + '=' + value + '\n')

# Function to condense
def CondenseEnvFile():
    last_multiline = None
    for input_line in input_file:
        trimmed = input_line.strip()
        if len(trimmed) <= 0 or trimmed.startswith('Environment size:'):
            output_file.write(trimmed + '\n')
            continue
        if input_line[0].isspace():
            if last_multiline:
                output_file.write(last_multiline)
                if not last_multiline[-1] == ';':
                    output_file.write(' ')
            last_multiline = trimmed
        else:
            if last_multiline:
                output_file.write(last_multiline + '\n')
                last_multiline = None
            output_file.write(trimmed)
            if not trimmed[-1] == '=':
                output_file.write('\n')

# Run the specified mode
if args.mode == 'expand':
    ExpandEnvFile()
else:
    CondenseEnvFile()

# Close up
input_file.close()
output_file.close()

sys.exit(0)
