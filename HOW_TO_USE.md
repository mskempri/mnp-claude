# How to Use the MNP Platform (A Walkthrough)

> This doc explains **what the app does and how to use it**, in plain
> language. If you want the engineering details (how the database is
> structured, what packages exist, etc.), see [README.md](README.md),
> [PHASES.md](PHASES.md), and [database/README.md](database/README.md)
> instead — this one's for everyone else.

## What is this, in one sentence?

It's the backend that handles **"I want to keep my phone number but switch
carriers"** — from the moment a customer asks for it, through all the
behind-the-scenes checks and waiting periods, to the moment their number is
actually live on the new carrier.

In the industry this is called **MNP — Mobile Number Portability**. If
you've ever kept your number when switching phone providers, a system like
this one ran in the background to make it happen.

## Who are the players?

| Term | What it means |
|---|---|
| **MSISDN** | Nerd word for "phone number" (e.g. `+306900000000`). You'll see it everywhere in this doc because it's what the system actually calls it. |
| **Donor network** | The carrier the customer is *leaving*. |
| **Recipient network** | The carrier the customer is *joining*. |
| **PAC code** | "Porting Authorization Code" — a short code the donor network gives the customer as proof they're allowed to leave. Like a permission slip. It expires after a while. |
| **Porting request** | The one "thing" that represents "customer X wants to move their number from carrier A to carrier B." Everything in this app revolves around this one object. |

## The journey of a single port request

Think of a porting request as moving through a pipeline of stages. Here's
the whole trip, start to finish:

```
  Customer submits
        │
        ▼
   [RECEIVED] ──────► instantly becomes...
        │
        ▼
  [VALIDATING]  ← we're checking: is the PAC code real and not expired?
        │          is this phone number being abused (too many requests
        │          lately)? does the donor network confirm this customer
        │          is real and in good standing?
        │
   ┌────┴────┐
   ▼         ▼
[APPROVED] [REJECTED]  ← rejected if any check above failed
   │
   ▼  (someone picks a cutover date/time)
[SCHEDULED]
   │
   ▼  (the scheduled time arrives)
[CUTOVER]  ← the actual "flip the switch" moment
   │
   ▼
[COMPLETED]  ← number is now live on the new carrier 🎉
```

At almost every stage, the customer (or the donor/recipient network) can
also **cancel** the request — except once `CUTOVER` has started. At that
point it's too late to back out.

## What actually happens at each stage (plain-English version)

1. **Customer submits a request.** They provide their phone number, which
   carrier they're leaving, which they're joining, their PAC code, and when
   they got that PAC code.
2. **We start a clock.** There's an overall SLA (service-level agreement)
   timer running the whole time a request is waiting on a decision — if it
   takes too long, an internal alert fires so someone can look into it.
3. **We check eligibility**, automatically, with no human involved:
   - Is the phone number a real, well-formed number?
   - Is the PAC code valid and not expired? (PAC codes are only good for a
     limited window after they're issued — think of it like a coupon with an
     expiry date.)
   - Has this same phone number had *too many* port attempts lately? (This
     guards against fraud — someone repeatedly trying to steal a number that
     isn't theirs.)
   - Does the donor network confirm this customer/account is actually valid
     and in good standing?
4. **Approved or rejected.** If every check passes, the request moves
   forward. If any check fails, it's rejected and the customer is told why.
5. **Scheduling.** Once approved, a cutover date/time gets set, and a
   countdown to that moment begins.
6. **Cutover.** When the scheduled moment arrives, the actual number
   transfer kicks off.
7. **Completed.** The number now officially belongs to the new carrier. We
   also quietly update our own "who owns this number" records so that if
   this same number is ever ported again in the future, we have a history
   of it.

Along the way, the right people get notified automatically at the right
moments — the customer gets told when their request is received, approved,
rejected, cancelled, or completed; the networks get told when they need to
take action (e.g. "get ready to hand this number off" or "this number is
now live").

## How do you actually *use* it?

The app exposes itself as a small set of things you can ask it to do (in
engineering terms, an "API" — think of it like a menu of actions):

- **"Submit a new port request."** You give it the phone number, the two
  carriers involved, the desired date, and the PAC code details. It hands
  you back a request with an ID and its current stage.
- **"Show me this request."** Look up a request by its ID to see what stage
  it's at.
- **"Show me all requests for this phone number."** Useful for a customer
  who's ported before.
- **"Something happened to this request — update it."** This is how you
  tell the system "the customer wants to cancel," "go ahead and schedule
  this for date X," or "the transfer just finished." The system itself
  decides what's *allowed* to happen next from there — you can't force an
  invalid move.
- **"Who currently owns this phone number?"** A separate, simple lookup: ask
  for a phone number, get back which carrier currently has it — but only if
  that number has actually been ported through this system before. If it's
  never been ported here, the honest answer is "we don't know," not a
  guess.

## What's *not* built yet, or built but not fully wired up

Being upfront about this stuff is more useful than pretending it's all
perfect:

- **Nobody automatically checks for expired timers on a schedule yet.**
  Someone (or some other scheduled job) has to manually trigger that check
  periodically. Today, nothing does that automatically.
- **If the notification-sending process crashes mid-send, that one
  notification can get stuck and never retried.** Rare, but possible.
- **We now track "who owns this number" (see above), but we don't yet use
  that information to double-check a customer's claim about which carrier
  they're leaving.** Someone could still submit a request claiming the
  wrong donor network and it wouldn't get caught by that specific check
  today (other checks still apply).
- **When a request gets blocked for looking like fraud, nobody gets
  alerted about it right now.** It's blocked, but silently.
- **The official holiday calendar used for calculating deadlines is
  incomplete** — a few moveable religious holidays aren't in there yet,
  pending confirmation of the correct dates.

None of these are "broken" — they're just conscious choices to ship the core
flow first and layer in the rest later. See [PHASES.md](PHASES.md) if you
want the full history of what was built in what order and why.
