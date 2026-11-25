# ZERO MERCY — Two-Month Release Plan

**Target date:** 2027-01-25  
**Project:** ZERO MERCY (Godot 4, 3D cyberpunk open world)  
**Release goal:** a stable, complete, playable first release—not a claim that every part of Earth or every planned feature is finished.

## Scope lock

The January release must prioritize one polished, playable campaign slice and the systems required to finish it. The entire real-world Earth, 70 hours of story, fully simulated global society, and native 9K on all hardware are long-term goals and are not realistic acceptance criteria for a two-month solo build.

## Milestones

### Week 1 — Stabilize the foundation (Nov 25–Dec 1)
- Open the project in the target Godot version and fix parser/runtime errors.
- Confirm the main scene, player controller, camera, input, HUD, save/load, and mission flow.
- Add a repeatable smoke-test checklist.
- Freeze new feature additions until critical startup blockers are resolved.

### Week 2 — Playable core (Dec 2–8)
- Complete movement, interaction, combat, enemy behavior, health, and checkpoints.
- Ensure mission objectives start, update, fail, and complete correctly.
- Make pause, settings, and restart flows usable.

### Week 3 — Campaign slice (Dec 9–15)
- Deliver the opening story arc with dialogue, objectives, combat encounters, and a clear ending.
- Connect phone UI, dialogue, and mission director to actual gameplay state.
- Persist player progress.

### Week 4 — World and traversal (Dec 16–22)
- Build one compact, dense, polished cyberpunk district with meaningful interiors and traversal.
- Add functional roads, traffic, ambient NPC schedules, and district streaming only where verified.
- Keep global Earth map as an overview/long-term expansion, not a fake claim of fully authored cities.

### Week 5 — Art and audio pass (Dec 23–29)
- Replace visible placeholders in the release district with coherent high-quality assets.
- Improve PBR materials, lighting, reflections, weather, VFX, animation, sound, and UI feedback.
- Profile performance and create scalable quality tiers.

### Week 6 — Content completion (Dec 30–Jan 5)
- Complete the scoped campaign missions, enemy variety, pickups, interactions, and rewards.
- Add tutorial/onboarding and clear player feedback.
- Verify save compatibility and recovery from interrupted sessions.

### Week 7 — QA and optimization (Jan 6–12)
- Run the project on target hardware.
- Fix crashes, broken scenes, missing assets, progression blockers, and severe frame drops.
- Test low/high graphics settings and resolution scaling.
- Do not advertise native 9K unless it has been captured and verified on capable hardware.

### Week 8 — Release candidate (Jan 13–19)
- Run a full playthrough from new game to campaign ending.
- Fix critical and high-priority bugs.
- Prepare controls, settings, credits, known issues, and release build.
- Freeze features.

### Final days — Jan 20–25
- Regression test the release candidate.
- Verify exported build on a clean machine.
- Publish only after launch blockers are cleared.

## Definition of done

- [ ] Project opens and runs in the declared Godot version.
- [ ] New game, save, load, pause, restart, and quit work.
- [ ] Core movement, combat, interaction, and mission progression work.
- [ ] The scoped campaign can be completed from beginning to end.
- [ ] No known progression-blocking bugs or repeatable crashes.
- [ ] Release district has no visible placeholder assets in critical player-facing areas.
- [ ] Graphics scale to the target hardware; 9K remains a high-end target, not a universal requirement.
- [ ] Exported build passes a clean-machine smoke test.

## Truthful status policy

A milestone is complete only after its implementation is committed and verified in a running build. A code file, shader, design document, or generated map alone does not count as a finished playable feature. This plan is a schedule, not evidence that any milestone has already passed.
