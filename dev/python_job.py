#!/usr/bin/env python

import subprocess
import os

node_file = os.environ["OAR_NODE_FILE"]
job_id = int(os.environ["OAR_JOB_ID"])

with open(node_file, "r") as file:
  lines = [ line.strip() for line in file.readlines() ]

  for node in lines:
    print("connect to {}".format(node))
    print("oarsh {} {}".format(node, "sleep 2h"))
    subprocess.call("oarsh {} 'nohup {} </dev/null >command.jid_{}.log 2>&1 &'".format(node, "sleep 2h", str(job_id)), shell=True)

# Main process
print("sleep for 2h")
subprocess.call("sleep 2h", shell=True)