# Estimate Poker for Salesforce

**Run Planning Poker where your team already works. No new tools. No new logins. No data leaving your org.**

---

## The one-liner

Estimate Poker is a real-time Planning Poker (Scrum Poker) app built natively on the Salesforce Platform. Agile teams size their backlog together — voting privately, revealing simultaneously, and recording every estimate as Salesforce data — without ever leaving Salesforce.

---

## Why teams need it

Estimation meetings quietly cost teams every sprint:

| The problem | What it looks like | What it costs |
|---|---|---|
| **Anchoring bias** | The first number spoken becomes everyone's number | Estimates that reflect one voice, not the team |
| **Seniority pressure** | Junior engineers defer instead of flagging risk | Missed complexity, blown sprints |
| **Meeting drift** | Endless debate with no mechanism to converge | Hours lost, decisions deferred |
| **No paper trail** | Estimates made out loud, never written down | Nothing to learn from in the retro |
| **Yet another SaaS tool** | A separate poker app, separate accounts, separate data | Procurement, security review, context-switching |

Estimate Poker makes voting **simultaneous, private-until-revealed, structured, and automatically recorded** — and it does it inside the system your team is already logged into.

---

## How it works

1. **Build a team** — an organizer creates a Team and adds members, each linked to their Salesforce user.
2. **Open a room** — a facilitator starts an estimation room with a shareable **room code** and picks a card scale.
3. **Load the backlog** — add stories one at a time or in bulk, each with title, description, and acceptance criteria.
4. **Vote** — every participant secretly picks a card, optionally adding a comment and a confidence level.
5. **Reveal** — the facilitator flips all cards at once; the app instantly shows the spread, average, median, and outliers.
6. **Discuss & finalize** — re-vote if opinions diverge, then lock in the final estimate and advance to the next story.

Everything updates **live for everyone in the room** — votes, reveals, new stories, and who's online — with no page refresh.

---

## Key features

### Real-time collaboration
Built on Salesforce Platform Events, every action propagates instantly to all participants. Remote teams get the feel of sitting around one table.

### Estimation scales for every team
- **Fibonacci** — `0, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89`
- **Modified Fibonacci** — `0, ½, 1, 2, 3, 5, 8, 13, 20, 40, 100`
- **T-Shirt Sizes** — `XS, S, M, L, XL, XXL`
- **Powers of 2** — `0, 1, 2, 4, 8, 16, 32, 64`
- **Custom values** — define your own

Plus the classic `?` (unsure) and `☕` (break) cards.

### Instant statistics on reveal
Average, median, full vote distribution, and automatic **outlier detection** so the team knows exactly where to focus the conversation.

### Confidence levels & comments
Voters record *how sure they are* and *why* — turning a bare number into real signal.

### Optional voting timer
Facilitators can run a countdown to keep sessions brisk and on schedule.

### Presence & reactions
See who's in the room right now, and send a quick acknowledgement to a teammate.

### Guided onboarding
First-time users get interactive walkthroughs, a searchable help center, and contextual tips — with built-in feedback capture so the guidance keeps improving.

### A permanent, reportable record
Every session, vote, comment, and final estimate is stored as native Salesforce records — ready for reports, dashboards, retrospectives, and downstream automation.

---

## Built for Salesforce, end to end

| | |
|---|---|
| **Native architecture** | Lightning Web Components, Apex services, and Platform Events — no middleware, no external servers |
| **Custom data model** | `Team__c`, `Team_Member__c`, `Estimation_Poker_Room__c`, `Room_Member__c`, `User_Story__c`, `Estimation_Vote__c` |
| **Real-time backbone** | Dedicated platform events for room, story, vote, team, and presence updates |
| **Security model** | Enforced through Salesforce sharing and three ready-made permission sets |
| **Your data stays home** | Estimates never leave your org — no third-party processor, no data residency questions |

---

## Roles & permission sets

| Role | Capabilities |
|---|---|
| **Team Member** | Join rooms, vote, comment, react, participate in live sessions |
| **Facilitator** | Everything a member can do, plus create and run rooms, manage stories, reveal votes, run the timer, and record final estimates |
| **Administrator** | Full control — manage teams, configure the app, oversee all rooms and data |

Each role ships as a Salesforce permission set — assign and go.

---

## Who it's for

- **Agile software teams** running sprint planning and backlog refinement
- **Salesforce delivery teams** (consultancies, ISVs, internal COEs) sizing user stories in the platform they build on
- **Project and PMO teams** that need estimation history for forecasting and reporting
- **Distributed teams** that need estimation to feel synchronous even when they're not

---

## Why choose Estimate Poker over a standalone tool

| | Standalone poker app | **Estimate Poker** |
|---|---|---|
| New logins & accounts | Yes | **None — uses Salesforce SSO** |
| Security review for a new vendor | Yes | **Already inside your trusted org** |
| Data location | Third-party cloud | **Your Salesforce org** |
| Reporting on estimates | Export & stitch together | **Native reports & dashboards** |
| Connects to your stories, sprints, records | Manual copy-paste | **Native Salesforce data** |
| Cost model | Per-user SaaS subscription | **Runs on infrastructure you already own** |

---

## In short

Estimate Poker turns a proven, fair, and genuinely fun estimation technique into a polished, real-time application that lives exactly where your team already works. Faster sessions. More inclusive decisions. A complete history of how every estimate was reached — all without adding another tool to your stack.

*Estimation, where your work already lives.*
