---
tags: [project]
id: example
repo: ~/Developer/example
hosts: ["[[entities/web01]]"]
created: 2026-10-01
updated: 2026-10-03
tracked: true
area: Projects
status: active
next_step: "Set up the nightly backup"
due: 2027-01-15
open_questions: ["Move to a hosting provider once there are real users?"]
reviewed: 2026-10-03
---
# Example: landing site

## Goal
A static site served by Nginx, deployed on every release.

## Current state
In production since 2026-10-03 (release `a1b2c3d`). Next step: the nightly backup.

## Actions
- [ ] TODO Nightly backup of the container, tested with a restore
- [x] DONE 2026-10-03 First production release, smoke tests OK

## Blockers
_None._

## Decisions
- 2026-10-02: a static site rather than a CMS. Nothing to patch on the server, and a release is just a folder.

## Ideas
_None._

## History
- 2026-10-03: production release `a1b2c3d`. [[raw/sessions/2026-10-03-example-first-release]]
