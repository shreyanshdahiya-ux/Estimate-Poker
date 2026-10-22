# Estimate Poker

A real-time **Planning Poker** application built natively on the Salesforce platform (Apex, Lightning Web Components, Platform Events). Teams create estimation rooms, vote privately on user stories, reveal votes simultaneously, review statistics, and record a final estimate, all inside Salesforce with no external services.

## Install

[![Install in Salesforce](https://img.shields.io/badge/Install%20in-Salesforce-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tf6000000UHWT)
[![Install in a Sandbox](https://img.shields.io/badge/Install%20in-Sandbox-5C6BC0?style=for-the-badge&logo=salesforce&logoColor=white)](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tf6000000UHWT)

Version 1.0 of the managed package (namespace `estpoker`). Use the first button for production and Developer Edition orgs, and the second for sandboxes. After installing, assign the permission sets and open the **Estimate Poker** app from the App Launcher. The [Onboarding Guide](docs/Onboarding-Guide.docx) walks through setup, roles and your first session.

## Project

- **Source API version:** 65.0
- **Project type:** Salesforce DX source for a first generation managed package (single package directory `force-app`, namespace `estpoker`)
- **Getting started:** [Onboarding Guide](docs/Onboarding-Guide.docx) (setup, roles, and how to run a session)
- **Further reading:** [Application Overview](docs/Application-Overview.docx) (non-technical guide)

## Features

- Private, simultaneous voting with a facilitator-controlled reveal
- Live updates (votes, reveals, stories, presence, timer) over Platform Events and `lightning/empApi`
- Estimation scales: Fibonacci, Modified Fibonacci, T-Shirt, Powers of 2, Custom
- Statistics after reveal: average, median, vote distribution, outlier detection
- Per-vote comment and confidence level, optional voting timer, online presence, member "likes"
- Story management: single and bulk create, reorder, skip, finalize estimate
- Built-in guidance: contextual help, searchable help articles, guided tours, feedback and progress tracking
- Role-based access through three permission sets

## Architecture

### Layered overview

```
 Lightning Web Components (UI)
   planningPokerApp ─ roomList ─ roomCreation ─ roomDashboard ─ estimationSession
   currentStory ─ storyManager ─ votingPanel ─ pokerCards ─ voteResults
   teamManagement ─ helpPanel ─ realtimeEventHandler
            │  @AuraEnabled                          ▲  lightning/empApi (subscribe)
            ▼                                        │
 Apex controllers (with sharing)                     │
   RoomController  StoryController  VotingController │
   TeamController  GuidanceController                │
            │                                        │
            ▼                                        │
 Services                                            │
   EstimationService   (scales, stats)               │
   ValidationService   (rules, permissions)          │
   PlatformEventPublisher ───────────────────────────┘
            │
            ▼
 Custom objects (data) + Platform Events (messaging)
```

### Apex classes

| Class                    | Responsibility                                                                                                    |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| `RoomController`         | Create, read, update and delete rooms; manage room members; set the current story; presence updates; member likes |
| `StoryController`        | Create (single and bulk), update, delete and reorder stories; story status; next pending story                    |
| `VotingController`       | Submit, delete and reset votes; reveal votes; finalize estimate; statistics; vote history; timer broadcast        |
| `TeamController`         | Create, update, deactivate and delete teams; manage team members and roles; user search                           |
| `GuidanceController`     | Help content by context, help search, guided tour steps, completion state, feedback                               |
| `EstimationService`      | Scale values, average, median, outliers, vote distribution, estimation report                                     |
| `ValidationService`      | Input validation, uniqueness checks, `canUserVote`, `canManageRoom`, finalize preconditions                       |
| `PlatformEventPublisher` | Single place that builds and publishes all Platform Events (supports queueing and batch publish)                  |

Every class has a matching `*Test` class.

### Data model

| Object                                              | Purpose                                                                                                                                                  |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Team__c`                                           | A group that estimates together (lead, department, active flag)                                                                                          |
| `Team_Member__c`                                    | Links a `User` to a `Team__c` with a role                                                                                                                |
| `Estimation_Poker_Room__c`                          | An estimation session: room code, scale, custom scale values, facilitator, current story. Status: Draft, Active, Paused, Completed, Archived             |
| `Room_Member__c`                                    | A participant in a room: role in room, online flag, can-vote flag, last activity                                                                         |
| `User_Story__c`                                     | An item to estimate: title, description, acceptance criteria, order, final and average estimate. Status: Pending, Discussing, Voting, Estimated, Skipped |
| `Estimation_Vote__c`                                | One member's vote on one story: value, numeric value, comment, confidence, revealed flag                                                                 |
| `Help_Content__mdt`                                 | Help center content and tour step content (ships with the package as custom metadata records)                                                            |
| `User_Guidance_Progress__c`, `Guidance_Feedback__c` | Per-user tour progress and feedback ratings                                                                                                              |

Relationships:

```
Team__c ─< Team_Member__c >─ User
Team__c ─ runs ─< Estimation_Poker_Room__c ─< Room_Member__c >─ User
                         │                          │
                         └─< User_Story__c ─< Estimation_Vote__c >┘
```

### Platform Events (real-time channel)

| Event                     | Used for                                           |
| ------------------------- | -------------------------------------------------- |
| `Poker_Vote_Event__e`     | Vote submitted, votes revealed, estimate finalized |
| `Poker_Story_Event__e`    | Story created, changed or selected                 |
| `Poker_Room_Event__e`     | Room status changes, timer actions                 |
| `Poker_Presence_Event__e` | Member online and offline, likes                   |
| `Poker_Team_Event__e`     | Team and membership changes                        |

Apex publishes through `PlatformEventPublisher`. On the client, `realtimeEventHandler` and `roomList` subscribe with `lightning/empApi` and the components refresh their state.

#### Platform event limits

Salesforce limits platform events per org: events **published** per hour, and events **delivered** per 24 hours. Delivery counts once per subscriber, and the app's channels are org-wide (every connected user receives every room's events and filters by room in the browser), so delivered events grow with the number of connected users. The allowance depends on the org's edition (a Developer Edition org allows 10,000 delivered per 24 hours and 20 concurrent streaming clients; production editions allow more).

Rough budget, for one room of 6 people estimating 10 stories: about 10 events published per story (votes, reveal, finalize, story selection), so about 100 published and about 600 delivered with 6 clients connected. Every additional connected user multiplies the delivered count.

How the app protects the allowance:

- **Event budget guard (`PlatformEventPublisher`).** When less than 15% of the hourly publish or daily delivery allowance remains, nice-to-have events are skipped: likes, voting timer broadcasts, presence and team events. Essential events (votes, reveal, reset, finalize, story selection, member changes and room status) keep publishing. A skipped or failed publish never fails the user's action.
- **No vote subscription on the room list or teams screens.** Those screens do not show votes, so they do not subscribe to the busiest channel.
- Events are published after commit, and most actions publish a single event.

To check usage, run `sf limits api display` and look at `DailyDeliveredPlatformEvents` and `HourlyPublishedPlatformEvents`.

### Lightning Web Components

| Component                                   | Role                                                                                     |
| ------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `planningPokerApp`                          | Top-level container (App Page, Home Page, Tab)                                           |
| `roomList`, `roomCreation`, `roomDashboard` | Browse, create and manage rooms (the dashboard plays start, pause, resume and end tones) |
| `estimationSession`                         | The live session shell                                                                   |
| `currentStory`, `storyManager`              | Show the active story; manage the story backlog                                          |
| `votingPanel`, `pokerCards`, `voteResults`  | Card selection, vote submission, revealed results and statistics                         |
| `teamManagement`                            | Teams and members                                                                        |
| `helpPanel`                                 | Contextual help, tours, feedback                                                         |
| `realtimeEventHandler`                      | Event subscription                                                                       |

### Security model

- Controllers run `with sharing`, and all queries and DML run in user mode (`WITH USER_MODE`, `as user`), so object and field access always follows the permission sets.
- Three permission sets:

| Permission set                 | Intended for                                                                                                                                                                       |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Estimation_Poker_Team_Member` | Join rooms, vote, view teams and rooms. Read-only on stories, rooms and members.                                                                                                   |
| `Estimation_Poker_Facilitator` | Everything a member can do, plus create and run rooms, manage stories and members, reveal, reset and finalize votes. Grants the **Facilitate Estimation Rooms** custom permission. |
| `Estimation_Poker_Admin`       | Full control of teams, rooms and data. Also grants the custom permission.                                                                                                          |

- **Facilitating a room needs both** the `Facilitate Estimation Rooms` custom permission (granted by the Facilitator and Admin sets) **and** being that room's facilitator. The room role alone is never enough, because it is stored in records and cannot be trusted as authorization. Assign the Facilitator permission set to anyone who will run rooms. A user who is listed as a room Facilitator but only holds the Team Member set sees the room as a participant and cannot change it.
- Page layouts are provided for the six main objects under `force-app/main/default/layouts`.

## Repository layout

```
force-app/main/default/
  classes/            Apex controllers, services and tests
  lwc/                Lightning Web Components
  objects/            Custom objects, fields and platform events
  applications/       Estimate Poker Lightning app
  tabs/               Estimation Rooms (LWC) plus object tabs
  customMetadata/     Help_Content__mdt records (help center content)
  permissionsets/     Admin, Facilitator, Team Member
  customPermissions/  Facilitate Estimation Rooms
  layouts/            Page layouts
config/               Scratch org definition
docs/                 Onboarding guide and application overview (Word)
package.xml           Manifest for metadata API deployment
```

## Getting started

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`)
- Node.js and npm (for LWC tests, linting and formatting)
- A Dev Hub (for scratch orgs) or a sandbox or Developer Edition org

### Install dependencies

```bash
npm install
```

### Deploy to a scratch org

```bash
sf org create scratch -f config/project-scratch-def.json -a poker-scratch -d
sf project deploy start --source-dir force-app
sf org assign permset -n Estimation_Poker_Admin
sf org open
```

### Deploy to an existing org

```bash
sf org login web -a my-org
sf project deploy start --source-dir force-app -o my-org
```

Or deploy through the manifest: `sf project deploy start --manifest package.xml -o my-org`.

### After deploying

1. Assign `Estimation_Poker_Team_Member`, `Estimation_Poker_Facilitator` or `Estimation_Poker_Admin` to users. Anyone who will create or run rooms needs the Facilitator (or Admin) set.
2. Open the **Estimate Poker** app from the App Launcher. It is included in source, together with its tabs (the `Estimation Rooms` tab hosts the `planningPokerApp` component).
3. Make sure Platform Events are enabled so live updates reach connected users.

## Development

| Task           | Command                                                                       |
| -------------- | ----------------------------------------------------------------------------- |
| Run Apex tests | `sf apex run test --test-level RunLocalTests --result-format human --wait 10` |
| LWC unit tests | `npm run test:unit`                                                           |
| LWC coverage   | `npm run test:unit:coverage`                                                  |
| Lint           | `npm run lint`                                                                |
| Format         | `npm run prettier`                                                            |

Husky and lint-staged run Prettier and ESLint on staged files at commit time.

## Typical session flow

1. A team and its members are created (`TeamController`).
2. A facilitator creates a room with a scale (`RoomController.createRoom`) and shares the room code. A voting timer (30s to 5m) can be started per story from the Facilitator Controls.
3. Stories are added singly or in bulk (`StoryController`).
4. The facilitator sets the current story. Members vote (`VotingController.submitVote`), and each vote publishes a `Poker_Vote_Event__e`, so everyone sees who has voted without seeing values.
5. The facilitator reveals votes (`revealVotes`). `EstimationService` calculates average, median, distribution and outliers.
6. The team discusses, re-votes if needed (`resetVotes`), then the facilitator finalizes (`finalizeEstimate`) and moves to the next story.
