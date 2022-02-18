#AUTO_PROVISIONING=1
SRC=oar3
# Enable the frontend to act as a node.
# In case of job deploy, the oarexec can be executed on the frontend.
FRONTEND_OAREXEC=false
LIVE_RELOAD=true
#SRC=oar2-src
#TARBALL="https://github.com/oar-team/oar/archive/refs/heads/master.tar.gz"
#TARBALL="https://github.com/oar-team/oar3/archive/refs/heads/master.tar.gz"
#TARBALL="https://github.com/oar-team/oar3/archive/3b06b64a4dbec62f1017963b62d619686c190a88.tar.gz"

# Config for installing oar2 with oar3
# Note that SRC must point to an oar2 folder
# The running oar server uses oar2, but one can use the oar3 scheduler
# MIXED_INSTALL=true
# SRC_OAR3=oar3
#TARBALL_OAR3="https://github.com/oar-team/oar3/archive/refs/heads/master.tar.gz"
