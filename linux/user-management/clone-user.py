#!/usr/bin/env python3
# --------------- Copyright (c) Takeoff Technical LLC 2022 -------------------
# Purpose: I wrote this script to setup my BeagleBone Black with a custom user.
#          The debian distribution for the bone includes a demo user: debian.
#          I use this script to clone that user into one of my own.
# Example: sudo ./clone-user.py -c debian -n tot -fn "Takeoff Technical"
# Note:    Be sure to call "sudo passwd <username>" after this call to set pw
# License: GPL v3
# ----------------------------------------------------------------------------

import os
import sys
import pwd
import grp
import argparse

# Read the command line inputs
parser = argparse.ArgumentParser(description="Script to create a new user in all the same groups as another.")
parser.add_argument(
    '-c',
    '--clone-user',
    dest='clone_user',
    required=True,
    type=str,
    help='The user (name) used as reference for group membership.'
)
parser.add_argument(
    '-n',
    '--new-user',
    dest='new_user',
    required=True,
    type=str,
    help='The new user to create.'
)
parser.add_argument(
    '-fn',
    '--full-name',
    dest='full_name',
    type=str,
    help='The full name of the new user.'
)
args = parser.parse_args()

# Verify the script is called with privilege (sudo or as root)
if os.geteuid() != 0:
    sys.stderr.write('Insufficient privelege!\n')
    sys.exit(1)

# Check that the clone reference user exists
try:
    clone_user = pwd.getpwnam(args.clone_user)
except KeyError:
    sys.stderr.write('Unable to find clone source user [%s]!\n' % args.clone_user)
    sys.exit(1)

# Check that the new user does not exist
try:
    new_user = pwd.getpwnam(args.new_user)
    sys.stderr.write('New user [%s] already exists!\n' % args.new_user)
    sys.exit(1)
except KeyError:
    pass

# Get all the groups the clone user is in
clone_groups = []

for group in grp.getgrall():
    if clone_user.pw_name in group.gr_mem and not clone_user.pw_name == group.gr_name:
        clone_groups.append(group.gr_name)

# Call adduser to get the job done
cmd = [
    'useradd', 
    '--shell',
    clone_user.pw_shell,
    '--create-home',
    '--user-group',
    '--groups',
    ','.join(clone_groups),
    args.new_user
    ]

if args.full_name:
    cmd.append('--comment')
    cmd.append('"' + args.full_name + '"')

print ('Command to run:\n    %s\n' % ' '.join(cmd))

choice = input('Shall we proceed? [y/n]')

if not choice.lower() in ['y', 'yes']:
    print('Operation cancelled.')
    sys.exit(0)

os.system(' '.join(cmd))

try:
    new_user = pwd.getpwnam(args.new_user)
    print ('User [%s] has been successfully created.' % new_user.pw_name)
except KeyError:
    print ('Failed to create user [%s]!' % args.new_user)
    sys.exit(1)

sys.exit(0)
