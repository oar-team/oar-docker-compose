#!/usr/bin/env python

import sys
from oar.lib import db
from oar.lib import MoldableJobDescription, AssignedResource, db, FragJob
from oar.lib.job_handling import set_job_start_time_assigned_moldable_id, set_job_state

job_id = sys.argv[1]
nodes = int(sys.argv[2])

mld = (
    db.query(MoldableJobDescription)
    .filter(MoldableJobDescription.job_id == job_id)
    .one()
)

set_job_start_time_assigned_moldable_id(job_id, 0, mld.id)

# In case of restart, we clear frag jobs so the job can be deleted
db.session.execute(FragJob.__table__.delete())
db.commit()

result = (
    db.query(AssignedResource).filter(AssignedResource.moldable_id == mld.id)
).all()

if result:
    print("Mld already assigned")
else:
    # Nodes ids start at 1
    for node in range(1, nodes + 1):
        db.session.execute(
            AssignedResource.__table__.insert(),
            {"moldable_job_id": mld.id, "resource_id": node},
        )
    db.commit()

set_job_state(job_id, "toLaunch")
