# Alarm Background

How BeYou's alarm system actually works — the mission-gated alarm, its backups, and all the
machinery that keeps it reliable despite AlarmKit's quirks. Read this before touching anything
under `Managers/AlarmScheduler.swift`, `Managers/AlarmService.swift`, `Managers/WakeSessionStore.swift`,
or the alarm-handling parts of `Views/MainAppView.swift`.

---

## 1. The goal

An alarm you **cannot dismiss without completing a mission**. It must:
- Ring reliably (foreground, background, and locked).
- Keep re-ringing if you silence/kill it without finishing the mission.
- Stop completely once you finish the mission — and **never** re-show the mission afterward.

The hard part is that **AlarmKit (iOS 26) is unreliable**:
- `stop`/`cancel` frequently fail with `Code=0` (it refuses to take an alarm back).
- There's a **per-app limit** on how many alarms can be scheduled.
- **No app code runs while the app is force-quit** — we can't cancel a ringing system alarm until the user engages.

The whole design works *around* these facts instead of trusting AlarmKit.

---

## 2. The moving pieces

### Primary alarm
The real alarm, scheduled with AlarmKit (`AlarmService.scheduleAlarm`). Recurring alarms use a
repeating relative schedule; one-time alarms use a fixed date. Its AlarmKit id **is** the user
alarm's id (`AlarmItem.id`).

### Backups (the "burst")
Extra one-shot AlarmKit alarms that re-ring after the primary, so you can't just silence it.
- **Tapered 60-alarm chain, ~35 minutes:** every **20s for the first 5 min** (15 backups) + every
  **40s for the next 30 min** (45 backups). See `backupOffsets` in `AlarmScheduler`.
- **Soonest-only:** only the **single next-upcoming alarm** ever carries a burst, to stay under
  AlarmKit's quota. Other enabled alarms are just their primary until they become soonest.

### Mission bridge (UserDefaults)
How a fired alarm knows what to show. Keyed by the firing alarm's id:
- `alarmMission_<id>` → the mission(s), pipe-joined (e.g. `"Item Search|Solve Math"`).
- `alarmItems_<id>` → the Item Search objects.
- `alarmBackupPrimary_<id>` → a backup's pointer to its **parent** alarm.

These are **our** data, not AlarmKit's. They're set when an alarm/backup is scheduled and
**removed when it's cancelled** (a local delete that always succeeds, even when AlarmKit's
cancel fails).

### WakeSession (`WakeSessionStore`)
One record per *firing*. Holds the parent alarm id, all the backup ids, `completedAt`,
`lastBackupFire`, and `validUntil`. It also maps every `alarmKitID → session`. Crucially it
**survives `cancelBackups`** (the bridge keys don't), so a late backup can still trace back to
its parent even after cleanup.

### The "fridge note" (`AlarmDoneStore`) — the source of truth for "done"
A tiny persisted set keyed `"<alarmId>|<yyyy-MM-dd>"`. Means "this alarm's mission was finished
on this day." This is what every backup checks before presenting a mission. Per-day, so finishing
today never silences tomorrow.

---

## 3. Lifecycle of one alarm

1. **Create/edit** → `AlarmScheduler.sync` → `schedule` (primary) + `refresh`.
2. **`refresh`** → `reconcile` (cleanup) + `refreshSoonestBackups`.
3. **`refreshSoonestBackups`** arms the burst for the soonest alarm **only if that specific alarm
   doesn't already have a live burst** (so a stale session from a *different* alarm can't block a
   new one — that was the `session=nil`/no-re-ring bug). Arming also **clears that day's fridge
   note** so a re-used alarm rings again.
4. **Fire** → AlarmKit alerts → `MainAppView` decides what to do (Section 4).
5. **Mission complete** → `completeMission` (Section 5).

---

## 4. Fire-time decision (`MainAppView`)

When an alarm fires (or the user taps it), `checkForAlertingAlarm` / `checkForPendingMission`
decide in this order:

1. **Mission already on screen?** → leave the current mission; if the audio loop is playing,
   silence the newcomer so it doesn't double up.
2. **Is the alarm's mission already done today?** (`isAlarmDone` → fridge note for the parent)
   → it's a leftover: **silence it + cancel its siblings** (`handleStray`). No mission.
3. **Is it a ghost?** (`isGhost`) → **silence it + sweep all ghosts** (`dismissGhost`). No mission.
4. **Otherwise** → present the mission.

### What counts as a ghost (`isGhost`)
An alarm is legitimate **only if**:
- it **has a mission id** (`alarmMission_<id>` exists — cancelling erases it, so "none" = cancelled), **and**
- it's the **wake-up check** (`mission == "Type Word"`) **or** it **resolves to a currently-saved alarm**.

Anything else is a **ghost**: a leftover whose alarm was deleted/edited/reinstalled-away but whose
AlarmKit alarm survived a failed cancel. We never present a mission for a ghost. (We deliberately
do **not** trust a stray mission id alone — it must also trace back to a real saved alarm.)

---

## 5. Completion (`completeMission`)

1. Resolve the fired alarm → its parent id.
2. **Set the fridge note** (`AlarmDoneStore.markDone(parent)`) — *persist first*. From here on,
   every leftover backup reads this and self-dismisses, even if the cancels below fail.
3. Mark the WakeSession completed.
4. **Best-effort** stop the ringing alarm + terminate the backups (may fail `Code=0` — that's fine).
5. If the alarm has **Wake-up Check** enabled → schedule a separate "type the word" alarm +10 min.
6. If it's a **one-time** alarm → disable it (a one-time alarm is "used up" only once completed).
7. `refresh()`.

The guarantee here is the **fridge note** in step 2 — it doesn't depend on the unreliable cancels.

---

## 6. Cleanup: reconcile + ghost sweep

`reconcile()` runs on **every app foreground and at launch**:
- Cancels backups belonging to **completed or expired** sessions and prunes those sessions.
- **`sweepGhosts()`** — cancels every scheduled alarm that's a ghost (no mission + no saved parent),
  so ghosts are usually killed *before* they can ring.

`sweepGhosts()` also runs the moment a ghost fires (`dismissGhost`), so one ghost firing cleans up
the whole leftover batch.

Sessions are kept ~1 hour after completion (so late leftovers still resolve), then pruned. The
fridge note keeps today + yesterday.

---

## 7. Continuous mission audio (`MissionAlarmAudio`)

AlarmKit alarms ring in short bursts with gaps. To make the alarm sound **continuous during the
mission**, we loop the alarm's `.caf` with `AVAudioPlayer`.

The catch: the phone has **one** audio channel, shared with AlarmKit. So:
- **On mission open / foreground:** start the loop. Activation can fail while AlarmKit owns audio,
  so it **retries**, and only silences the system alarm once the loop is confirmed playing.
- **On background/lock (`scenePhase == .background`):** **stop the loop and release the audio
  channel.** This is essential — a backgrounded app that keeps the audio session **mutes the
  system backups** (they fire and wake the screen but make no sound). Releasing it lets the real
  alarms ring while you're away.
- **On completion:** stop the loop.

Rule of thumb: the loop only "owns" the audio **while you're looking at the mission**; the moment
you leave/lock, it hands audio back so the real alarms can ring.

---

## 8. AlarmKit limitations we design around

| Limitation | Symptom | How we handle it |
|---|---|---|
| `stop`/`cancel` fail (`Code=0`) | Backups won't go away | Don't depend on cancel — fridge note + ghost guard make leftovers harmless |
| Per-app alarm quota | A new alarm silently fails to schedule | Soonest-only backups; sweep ghosts to free slots |
| No code runs while force-quit | Can't silence a ringing system alarm | Pre-schedule the burst; guard/sweep run the moment the user engages |
| One shared audio channel | Loop mutes the alarms | Release the audio session on background |

---

## 9. Known limits / edge cases (by design)

- **Stray ring while the app is fully closed:** a leftover that fires while the app is closed/untapped
  will **ring once** (iOS limit — no code runs to stop it). But when you open/tap it, the guard
  dismisses it — **no mission, no loop.** Opening the app at any point sweeps ghosts before they fire.
- **Wake-up check is independent:** it's a standalone alarm scheduled at completion. Deleting the
  source alarm does **not** cancel a pending wake-up check, and the check's in-app loop audio falls
  back to **Default** (it carries no pointer to the original alarm's sound). *(Both are candidate fixes.)*
- **Recurring alarms:** the fridge note is per-day, and the primary keeps its mission id across days,
  so completing today never affects tomorrow — it rings fresh each day.
- **Migration wipe:** on first launch of a new build, `migrateWipeIfNeeded` terminates all existing
  AlarmKit alarms and rebuilds from saved alarms (clears pre-existing ghosts from older logic).

---

## 10. Key files

- `Managers/AlarmScheduler.swift` — scheduling, backups, fridge note (`AlarmDoneStore`), reconcile,
  ghost guard/sweep, completion.
- `Managers/AlarmService.swift` — thin AlarmKit wrapper (schedule/stop/cancel/terminate, alert sounds).
- `Managers/WakeSessionStore.swift` — per-firing session records + the alarm→session map.
- `Managers/MissionAlarmAudio.swift` — the continuous mission audio loop.
- `Views/MainAppView.swift` — fire-time decision (present / silence / dismiss ghost), audio lifecycle.
- `Views/Alarm/AlarmDismissFlowView.swift` — the mission flow + completion recording.

---

## 11. Diagnostics

Console tags (strip before a clean release if desired):
- `⏰ SCHEDULER:` — scheduling / arming / cancelling.
- `🔔 SESSIONLOG PRESENT/DISMISS/COMPLETE:` — what a fired alarm resolved to and the decision made.
- `👻 SCHEDULER: Swept ghost alarm` — a ghost was cancelled.

`Failed to stop/cancel alarm … Code=0` lines are **expected and harmless** — they're AlarmKit
refusing a cancel; the fridge note + ghost guard absorb them.
