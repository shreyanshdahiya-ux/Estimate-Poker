# Estimate Poker — Application Overview

*A non-technical guide to what the app does and who it's for.*

---

## What is Estimate Poker?

Estimate Poker is a **team collaboration app built inside Salesforce** that helps software and project teams agree on how much effort a piece of work will take. It's a digital version of "Planning Poker" (also called Scrum Poker) — a popular, game-like technique used in agile teams to estimate work fairly and quickly.

Instead of one loud voice dominating the conversation, **everyone votes privately and at the same time**, then all votes are revealed together. This reduces bias, sparks healthy discussion when people disagree, and helps the team reach a shared, confident estimate.

Because it lives directly in Salesforce, teams don't need a separate third-party tool — estimation happens right alongside the rest of their work, using their existing Salesforce logins and security.

---

## The problem it solves

When teams plan their work, they need to estimate how big or complex each task is. Done poorly, this leads to:

- **Anchoring bias** — the first person to speak influences everyone else.
- **Pressure** — junior team members defer to senior ones instead of voicing concerns.
- **Slow, unfocused meetings** — endless debate without a clear way to reach agreement.
- **Lost history** — estimates are made verbally and never recorded.

Estimate Poker addresses all of these by making voting **simultaneous, private-until-revealed, structured, and automatically recorded**.

---

## How it works — the basic flow

1. **Set up a team.** An organizer creates a team and adds members (each linked to their Salesforce user).
2. **Create a room.** A facilitator opens an estimation "room" — a virtual table where a session takes place. Each room gets a shareable **room code** so members can join.
3. **Add the work to estimate.** The facilitator loads in the list of "stories" (the tasks or features to be estimated), either one at a time or in bulk.
4. **Vote.** For each story, every participant secretly picks a card representing their estimate. They can optionally add a comment and indicate how confident they are.
5. **Reveal.** Once everyone has voted, the facilitator reveals all cards at once. The app instantly shows the spread of votes, the average, the median, and flags any unusual outliers.
6. **Discuss & finalize.** If votes differ widely, the team talks it through and re-votes. When they agree, the facilitator records the **final estimate**, and the app moves on to the next story.
7. **Repeat** until all stories are estimated.

Everything updates **live for everyone in the room** — when someone votes, the others see it happen in real time without refreshing their screen.

---

## Key features

### Real-time, live sessions
Votes, reveals, new stories, and who's online all update instantly across every participant's screen. It feels like sitting at the same table even when the team is remote.

### Multiple estimation scales
Teams can choose the card values that suit them:
- **Fibonacci** (0, 1, 2, 3, 5, 8, 13, 21…) — the classic agile scale
- **Modified Fibonacci** (0, ½, 1, 2, 3, 5, 8…)
- **T-Shirt Sizes** (XS, S, M, L, XL, XXL)
- **Powers of 2** (1, 2, 4, 8, 16…)
- **Custom values** defined by the team

Special cards like **"?"** (unsure) and **"☕" (coffee break)** are also available.

### Automatic statistics
After votes are revealed, the app calculates the **average**, the **median**, the **distribution** of votes, and highlights **outliers** — votes far from the group — so the team knows exactly where to focus discussion.

### Confidence levels and comments
Voters can flag how confident they feel and leave a note explaining their reasoning, giving richer context than a number alone.

### Optional voting timer
Facilitators can turn on a countdown timer to keep voting brisk and meetings on schedule.

### Presence and reactions
The app shows who's currently online in the room, and members can send a quick "like" to acknowledge a teammate.

### Built-in help and guided tours
First-time users get **guided walkthroughs**, a searchable **help center**, and contextual tips. The app even collects feedback on how helpful the guidance was, so it can be improved over time.

### Permanent record
Every session, vote, and final estimate is stored as Salesforce data. Teams can revisit the **history** of how an estimate was reached — useful for reporting, retrospectives, and improving future planning.

---

## Who uses it — the roles

The app recognizes three types of users, each with appropriate permissions:

| Role | What they can do |
|------|------------------|
| **Team Member** | Joins rooms, votes on stories, leaves comments, and participates in sessions. |
| **Facilitator** | Everything a member can do, plus creates and runs rooms, manages stories, reveals votes, runs the timer, and records final estimates. |
| **Administrator** | Full control — manages teams, configures the app, and oversees all rooms and data. |

---

## The main building blocks (in plain terms)

The app keeps track of a few simple concepts:

- **Team** — a group of people who estimate together.
- **Team Member** — a person who belongs to a team.
- **Room** — a single estimation session, with its own code, chosen card scale, and settings.
- **Room Member** — a participant currently in a given room.
- **Story** — an individual task or feature being estimated, with a title, description, and acceptance criteria.
- **Vote** — one person's estimate for one story, including their card value, optional comment, and confidence.

These connect naturally: a *team* runs a *room*, the room contains *stories*, and each story collects *votes* from the *room members*.

---

## Why build it in Salesforce?

- **No extra tools or logins.** Teams already in Salesforce can estimate without leaving it.
- **Trusted security.** Access follows Salesforce's existing user permissions — people only see what they're allowed to.
- **Data stays with you.** Estimates and history live in your own Salesforce environment, not a third-party service.
- **Connects to your work.** Because estimates are Salesforce records, they can feed into reports, dashboards, and other processes.

---

## In short

Estimate Poker turns the proven, fun, and fair technique of Planning Poker into a polished, real-time app that lives where your team already works. It makes estimation faster, more inclusive, and fully documented — helping teams plan with more confidence and less friction.
