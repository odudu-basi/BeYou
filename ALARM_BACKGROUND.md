# Alarm Background

How BeYou's alarm system works — written so **anyone** can follow it, even with no coding
background. It explains what the alarm must do, why it used to be fragile, and the simpler,
sturdier design we're moving to.

Files to know: `Managers/AlarmScheduler.swift`, `Managers/AlarmService.swift`,
`Views/MainAppView.swift`, `Views/Alarm/AlarmDismissFlowView.swift`.

---

## 1. What the alarm has to do

An alarm you **can't turn off without doing a mission** (take a photo, solve math, etc.). It must:

- **Ring** reliably — app open, app closed, or phone locked.
- **Keep ringing** if you silence or force-quit it without finishing the mission.
- **Go completely quiet** the moment you finish the mission — and **never** pop the mission up again.

Simple to say. Hard to do — because of the phone's alarm system (Apple's **AlarmKit**).

---

## 2. Why this is hard (in plain words)

Think of the app as a **teacher** and each alarm as a **student** who raises their hand (rings) at
a set time. To keep ringing even if you force-quit, we schedule a **burst of ~60 students** over
35 minutes (one every 20–40 seconds). *(This is normal — other alarm apps do the same.)*

Apple's alarm system has three annoying rules:

1. **The teacher can't ask a student anything after they're seated.** When an alarm rings, the
   phone only tells us its **ID number** — nothing about which mission or sound it should use.
   *(We confirmed this in Apple's code: a ringing alarm gives back only its id, time, and
   on/off state — none of the extra info we attached.)*
2. **"Sit down" doesn't always work.** Telling an alarm to cancel often silently fails. So we can
   never fully trust "cancel."
3. **If you force-quit the app, the teacher leaves the room.** No app code runs, so a leftover
   alarm can ring once before we get a chance to stop it.

Our whole design works **around** these rules instead of trusting them.

---

## 3. The old design, and why it caused your bugs

The old approach kept all the instructions on **sticky notes on the teacher's desk** — dozens of
little saved values, plus **two** separate "is it done?" systems, plus lists of which backups
exist. Every time an alarm rang, it **ran back to the desk** to read the notes.

That means **many separate things all had to stay perfectly in sync.** When they didn't, you got:

- **Wrong mission / wrong sound** — a leftover alarm read a note that had already been changed.
- **Mission that won't go away** — the two "done" systems disagreed, so leftovers didn't know it
  was finished and kept popping the mission.
- **Chaos if you edit then force-quit** — the teacher was halfway through rewriting 60 notes when
  the app died, so the notes and the real alarms no longer matched.

The lesson: **too many moving parts, all depending on the app staying alive.**

---

## 4. The new design (simple + sturdy)

Two ideas fix almost everything:

### Idea 1 — One small "who owns this?" phonebook
Instead of dozens of scattered notes, we keep **one tiny list** that answers a single question:

> "Alarm id `X` belongs to **which** of the user's alarms, and **which morning's** ringing is it?"

It's written **all at once, in one go** (not 60 separate scribbles). So there's almost nothing to
fall out of sync, and if the app dies mid-write, at most this **one** list is briefly stale — and
we fix it automatically next time the app opens.

In the code this is **`AlarmOwnerMap`** (in `AlarmScheduler.swift`). Each entry says:
`ownerAlarmId` (which user alarm) + `occurrenceKey` (which day/time, e.g. `2026-06-30-01:26`).

### Idea 2 — Read the truth from one place
Once we know **which user alarm owns** a ringing alarm, we read its **mission, items, and sound**
straight from the user's saved alarm settings — the **one real source of truth** — instead of from
copied sticky notes that can drift.

And "**is it done?**" becomes **one** checklist: *"Did owner `X` finish the `2026-06-30-01:26`
ringing? yes/no."* Every one of the 60 backups checks that **same** box. One box, no disagreement.

**The result:** two tiny lists (the phonebook + the done-checklist) instead of five tangled
systems. Killing the app can't break it, because the real truth lives in the saved alarms and in
the phone's own alarm list — and the app just re-checks those when it opens.

---

## 5. How each old bug dies

| Old bug | Why it happened | Why it's gone |
|---|---|---|
| Wrong mission / sound | leftover read an overwritten note | reads the owner's **real settings**, which don't get overwritten |
| Mission won't go away | two "done" systems disagreed | **one** done-checklist everyone shares |
| Edit + force-quit chaos | notes half-rewritten | one atomic write; the app **re-syncs from truth** on next open |
| Ghost/orphan alarms | lost track of which backups exist | we find them by **owner** in the phonebook |

---

## 6. Where we are (migration status)

We're moving to the new design in small, safe steps so nothing breaks at once:

- **Phase 0 — ✅ Done.** Confirmed the phone won't give back our attached info, so the "phonebook"
  approach is the right one.
- **Phase 1 — ✅ Done.** Built the one phonebook (`AlarmOwnerMap`) and started filling it every time
  an alarm/burst is scheduled. *(It's being written and kept tidy, but nothing reads from it yet —
  the old notes still run in parallel, so behavior is unchanged and safe.)*
- **Phase 2 — ✅ Done.** The app now **reads** the mission, items, and sound from the owner's real
  saved-alarm settings (via the phonebook), through one resolver (`AlarmScheduler.resolveFiring`).
  A leftover backup can no longer show a **stale mission or play the wrong sound** after an edit —
  it always uses the owner's current settings. *(The old mission notes are still written for the
  wake-up check's fallback; they're removed for good in Phase 5.)*
- **Phase 3 — ✅ Done.** Added the single done-checklist (`OccurrenceCompletionStore`), keyed by
  `ownerAlarmId + occurrenceKey`. Completion now marks **one** box that **every** backup of that
  firing checks (`AlarmScheduler.isOccurrenceDone`), so a straggler can't disagree with the primary
  — the fix for the **mission that won't go away**. *(The two old "done" systems still run as a
  fallback for alarms scheduled before this build; removed in Phase 5.)*
- **Phase 4 — ✅ Done.** Cancellation is now **by owner** (via the phonebook), so orphaned backups
  from an earlier re-arm are always found and stopped — not just whatever the old id-list
  remembered. And every time the app opens, `healFromTruth` sweeps the phone's real alarm list:
  anything whose owner is gone/disabled, or whose firing is already done, gets cancelled. This is
  what makes a **force-quit-mid-edit self-correct** — the next open cleans up the mess.
  - **Fail-safe hardening (✅):** `healFromTruth` now uses a **read-safe** load of the alarm list
    (`loadAlarmsChecked`) that tells "genuinely no alarms" apart from "couldn't read." It only treats
    "owner is gone" as a real deletion when the list read **cleanly and non-empty** — so a bad/empty
    read can never be mistaken for "everything was deleted" and wipe your backups (which would leave
    only primaries → "rings once, then never"). It **fails toward keeping alarms**, never silencing
    one. The "already done" and "true ghost" sweeps still always run.
- **Per-alarm bursts (✅).** Every enabled alarm now carries its **own** independent backup burst
  (see §7), replacing the old "only the soonest alarm gets a burst" scheme — verified safe by a
  capacity test (AlarmKit holds ≥1500 alarms). Removed `refreshSoonestBackups` + the `liveBurst`
  guard + `currentBackup*` tracking. Also: **saving an alarm now shows a spinner until its whole
  burst is confirmed on the phone** (see §"Saving an alarm"), so killing right after Save is safe.
- **Phase 5 — 🚧 In progress.**
  - **5a ✅ Done.** Deleted `AlarmDoneStore` (the old time-windowed "fridge note") entirely — it was
    fully superseded by the done-checklist. One whole system gone.
  - **5b — Deferred until on-device testing.** `WakeSessionStore` and the per-alarm sticky notes
    are still doing **load-bearing timing work** (knowing when a burst is "live", cleaning up an
    *ignored* burst after its window, and letting a straggler self-dismiss after cancellation).
    Removing them means reimplementing that timing on top of the phonebook + checklist, which can't
    be proven correct just by compiling. So they stay until phases 1–5a are validated on a real
    device, then they'll be retired carefully.

Each phase can be shipped and tested on its own.

---

## 7. Backups, sound, and force-quit (still true in the new design)

- **The burst (per-alarm):** **every enabled alarm** carries its **own** ~60-backup burst, armed
  independently for its next fire. We measured AlarmKit's ceiling at **≥ 1500 simultaneous alarms**
  (even densely packed), so there's no need to ration bursts. This replaced the old "only the
  soonest alarm gets a burst" scheme, whose global re-pointing was a source of bugs (a firing alarm
  could tear down another's — or its own — burst). Now bursts are independent: one alarm can never
  affect another's. `refreshAllBursts` arms/keeps each alarm's burst; `ensureBurst` skips one that's
  already armed or actively firing.
- **Continuous sound:** during the mission we loop the alarm sound ourselves so it's gapless. When
  you **background or lock** the phone, we **let go of the audio** — otherwise the app would
  accidentally **mute** the real backup alarms. (`MissionAlarmAudio`.)
- **Force-quit ring-once:** a leftover can ring **once** while the app is fully closed (the phone
  won't let our code run to stop it). The instant you open/tap it, it's recognized as already-done
  and dismissed — no mission.

## Saving an alarm waits until it's fully armed

Setting up an alarm (removing the old one, scheduling the primary, and scheduling all ~60 backups)
happens by talking to iOS, which takes a few seconds. If the app is **killed before that finishes**,
the alarm can be left half-scheduled (won't ring, or rings with no backups) until the next app open.

To prevent that, the **Save button shows a spinner and stays blocked until iOS confirms the whole
burst is really scheduled** (`AlarmScheduler.syncAwaiting` → `AlarmService.awaitRegistered`, which
polls the live alarm list). A **30-second failure-only safety net** guarantees the spinner can never
run forever. Net effect: by the time the sheet closes, the alarm is fully armed.

Four reliability measures make that window as small and robust as possible (the fix for "sometimes
doesn't ring until I open the app" — which happens because a **backgrounded app is suspended within
seconds**, freezing any half-finished scheduling, exactly like a force-quit):
- **Parallel scheduling** — the ~60 backups are scheduled concurrently (a task group), so the burst
  lands in ~1–2s instead of ~15s one-at-a-time. Much smaller window to get cut off.
- **Primary verify-and-retry** — the primary (the alarm that rings at the exact time) is retried up
  to 3× until iOS confirms it's on the books, instead of a swallowed failure silently dropping it.
- **Background-time assertion** — `beginBackgroundTask` around Save, so if the user backgrounds the
  app mid-schedule, iOS grants extra time to finish instead of suspending immediately.
- **5-second minimum floor** (`minSaveDuration`) — the spinner is held for **at least 5 seconds**,
  even when scheduling finishes faster. It's a *floor*, not a fixed wait: `max(real time, 5s)`, so a
  slow schedule still waits as long as it needs. Those 5s cover iOS's durable-commit window (the gap
  between "confirmed in the live list" and "persisted"), and — paired with the background-time
  assertion — guarantee a **protected execution window** so a fast Save-then-leave can't cut it short.

The unavoidable truth underneath: **scheduling can only happen while the app is running** (AlarmKit
requires it). Once an alarm is genuinely on iOS's books it rings regardless of app state; the whole
job is getting it there before the app is suspended/killed — hence "fast + protected + verified."

Trade-off: every Save now shows a ≥5s spinner. For an alarm app that's an acceptable price for
reliability; `minSaveDuration` can be tuned down (e.g. 3s) now that scheduling itself is fast.

---

## 8. Key files

- `Managers/AlarmScheduler.swift` — scheduling, the backup burst, the new `AlarmOwnerMap`, cleanup,
  completion.
- `Managers/AlarmService.swift` — thin wrapper around Apple's AlarmKit (schedule/stop/cancel, sounds).
- `Views/MainAppView.swift` — decides what to do when an alarm rings (show mission / dismiss leftover).
- `Views/Alarm/AlarmDismissFlowView.swift` — the mission screens + recording completion.

---

## 9. Reading the logs

Filter the Xcode console by these tags:

- `⏰ SCHEDULER:` and `⏰ SCHEDULER[xxxx]:` — scheduling / editing / arming / cancelling. The
  `[xxxx]` is the last 4 characters of an alarm's id, so you can follow **one** alarm end-to-end.
- `⏰ TEARDOWN[xxxx]:` — removing an old registration before re-adding (look for `⚠️ TIMED OUT`).
- `🔔 SESSIONLOG PRESENT/DISMISS/COMPLETE:` — what a ringing alarm resolved to and the decision made.

Lines like `Failed to stop/cancel … Code=0` are **expected and harmless** — that's just Apple's
alarm system refusing a cancel, which the new "done-checklist" is designed to shrug off.
