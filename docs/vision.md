# Reclamation Day — vision

## Core fantasy

Earth has passed an environmental tipping point. The Balancer, a melancholy shadow-like spirit, appears without explanation. Its presence draws in surrounding life: the world decays behind it while the spirit grows larger and more powerful. Humans resist, from farmers to organized forces and eventually aircraft and nuclear weapons. The player should feel increasingly overwhelming without victory becoming automatic; the long-term fantasy extends beyond the local demo into a wider escalation.

The long-term reveal remains undecided; renewal through the Balancer releasing accumulated life as vegetation and returning wildlife is one possibility.

## Current demo

One seamless region starts in an enclosed wheatfield, then runs north through an orchard/farm approach, a contemporary European village, and a city. Wheat provides early growth; a farmer arrives after 30 active gameplay seconds. Draining him requires the Balancer to reach his height. Break his endurance and stay close through full consumption to open the gate; this continues the same run, not a separate victory. Wheat, farm trees, and farm fences contribute to finite regional life; the farmer does not. Farm fences become drainable only after the gate unlocks, subject to normal size eligibility. Human and tank directors start only after the opening, with their escalation clocks beginning then. Pauses and growth choices do not advance the opening clock.

The city contains 16 blocks and 49 buildings, including eight towers up to 125 m, two parks, police and tanks, 48 parked cars, and eight route-following traffic cars. Beyond the farm gate, the region is freely accessible: local resistance supplies danger, and approach and retreat remain real choices. City and skyscraper-scale escalation are part of the current local demo, not a change to the larger fantasy. Run pacing is not yet validated after the expansion.

Play is mouse-orbit third person. The Balancer moves camera-relative, turns toward movement, and drains nearby eligible life automatically. Model volume is approximated by one enclosing rectangular box. An object's life equals its volume times a shared life density and an editable life modifier, initially 1. The Balancer needs at least 20% of an object's original volume to drain it. Absorbed life adds 10% of its equivalent volume to the Balancer; visible scale is the cube root of volume growth. Drain reach scales linearly with visible model scale. Hunger is exactly coefficient × model scale × hunger upgrade multiplier; every eligible target receives this full rate independently. The main-demo coefficient is 0.051 life/s at scale 1. Opening wheat has one-third drain efficiency, preserving its life rewards and timing: a patch takes 10 seconds to visibly wither at starting scale 0.5, or about 6.1 seconds at farmer height before accounting for growth during draining; its remaining 80% life transfers over one further active second. Farmer drain efficiency is 0.03, giving one-third the former effective endurance at a fixed hunger rate, with unchanged rewards. Movement speed and acceleration scale with the square root of model scale relative to initial scale and with the movement upgrade multiplier, without upper caps. Main-demo spawn speed is about 1.824 m/s with 7.295 m/s² acceleration; speed reaches about 2.339 m/s at farmer height and 3.308 m/s at twice farmer height. Relative body-length speed decreases as the Balancer grows. Upgrade choices appear at recurring growth-volume thresholds while the run is active. Human and tank attacks can end the run. The objective is the finite life placed in the region: absorb 90% to trigger a brief renewal and end the run, while spawned humans and tanks yield growth but do not count toward that objective. Retry starts a fresh run. Permanent progression is deferred.

Props contribute to the finite regional objective alongside larger targets. Grass and batched ground cover are decorative; their draining is deferred. Objects collapse once 20% of their life has been drained. The remaining 80% is awarded as rubble reaches the Balancer, or automatically over one active second during collapse for objects without collectible rubble, including wheat. Only actually absorbed life counts toward growth and regional completion. Remains are wooden vegetation and objects, humanoids, or rubble for structures, rocks and mixed materials. Renewal of collapsed targets is deferred.

Tone is dark and melancholy, with a shadowy, grim-reaper-like silhouette; the spirit's origin stays open to religious or evolutionary interpretation. Presentation is fixed dawn/sunrise twilight: an orange sun and warm low horizon against a cold blue-gray upper sky. Mist is a low world-space layer, so horizon paths fade while upward views keep a clearer sky; lamps diffuse and disappear with distance. No day-night cycle.

The developer owns visual, gameplay, and pacing acceptance through playtesting. Full UI, menu, and audio polish follows the environment and gameplay first pass.

Space provides a short directional phase with invulnerability during travel and a cooldown. It remains available after the farm gate opens; phase readiness and farmer endurance share the normal run HUD. Actual damage uses a brief camera shake, red flash, and hurt vocal; phase-blocked hits do not trigger feedback.

## Later ideas

Not current demo requirements:

- Expand beyond the local city to the whole Earth; aircraft and nuclear attacks remain later escalation.
- Roguelike replayability with permanent upgrades across runs.
- Failure meaning changes with the scale reached, including different game-over messages.
- Reveal renewal gradually as the Balancer grows.
- Open with gloomy factories and environmental damage, scored by machinery hum rather than music.
- Begin as a cell feeding on CO₂.
- Release absorbed life during a run to heal a region or restore animals.
- Add an active life/decay blast that turns weapons or aircraft into vegetation.
- Offer destructive and restorative paths with different endings, or a path where humans accept the Balancer.
- Try first-person play after judging the third-person demo.
- Continue beyond planetary renewal into conflict with gods and eventual defeat; this arc is not yet reconciled with the Earth-renewal victory.

Working title: **Reclamation Day**. The developer cited **Unharvest** as inspiration; Vampire Survivors is a reference for movement-led play and upgrade choices, not a system to reproduce.
