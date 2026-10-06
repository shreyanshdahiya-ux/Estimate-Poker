# Estimate Poker

A real-time **Planning Poker** application built natively on the Salesforce platform (Apex, Lightning Web Components, Platform Events). Teams create estimation rooms, vote privately on user stories, reveal votes simultaneously, review statistics, and record a final estimate, all inside Salesforce with no external services.

- **Source API version:** 60.0
- **Project type:** Salesforce DX, unmanaged source (single package directory `force-app`, no namespace)
- **Further reading:** [Application Overview](docs/Application-Overview.md) (non-technical guide), [Marketing Overview](docs/Marketing-Overview.md)

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
   teamManagement ─ helpPanel ─ soundPlayer ─ realtimeEventHandler
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

| Class | Responsibility |
|-------|----------------|
| `RoomController` | Create, read, update and delete rooms; manage room members; set the current story; presence updates; member likes |
| `StoryController` | Create (single and bulk), update, delete and reorder stories; story status; next pending story |
| `VotingController` | Submit, delete and reset votes; reveal votes; finalize estimate; statistics; vote history; timer broadcast |
| `TeamController` | Create, update, deactivate and delete teams; manage team members and roles; user search |
| `GuidanceController` | Help content by context, help search, guided tour steps, completion state, feedback |
| `EstimationService` | Scale values, average, median, outliers, vote distribution, estimation report |
| `ValidationService` | Input validation, uniqueness checks, `canUserVote`, `canManageRoom`, finalize preconditions |
| `PlatformEventPublisher` | Single place that builds and publishes all Platform Events (supports queueing and batch publish) |

Every class has a matching `*Test` class.

### Data model

| Object | Purpose |
|--------|---------|
| `Team__c` | A group that estimates together (lead, department, active flag) |
| `Team_Member__c` | Links a `User` to a `Team__c` with a role |
| `Estimation_Poker_Room__c` | An estimation session: room code, scale, custom scale values, timer settings, facilitator, current story. Status: Draft, Active, Paused, Completed, Archived |
| `Room_Member__c` | A participant in a room: role in room, online flag, can-vote flag, last activity |
| `User_Story__c` | An item to estimate: title, description, acceptance criteria, order, final and average estimate. Status: Pending, Discussing, Voting, Estimated, Skipped |
| `Estimation_Vote__c` | One member's vote on one story: value, numeric value, comment, confidence, revealed flag |
| `Help_Article__c`, `Help_Content__mdt` | Help center content and tour step content |
| `User_Guidance_Progress__c`, `Guidance_Feedback__c` | Per-user tour progress and feedback ratings |

Relationships:

```
Team__c ─< Team_Member__c >─ User
Team__c ─ runs ─< Estimation_Poker_Room__c ─< Room_Member__c >─ User
                         │                          │
                         └─< User_Story__c ─< Estimation_Vote__c >┘
```

### Platform Events (real-time channel)

| Event | Used for |
|-------|----------|
| `Poker_Vote_Event__e` | Vote submitted, votes revealed, estimate finalized |
| `Poker_Story_Event__e` | Story created, changed or selected |
| `Poker_Room_Event__e` | Room status changes, timer actions |
| `Poker_Presence_Event__e` | Member online and offline, likes |
| `Poker_Team_Event__e` | Team and membership changes |

Apex publishes through `PlatformEventPublisher`. On the client, `realtimeEventHandler` and `roomList` subscribe with `lightning/empApi` and the components refresh their state.

### Lightning Web Components

| Component | Role |
|-----------|------|
| `planningPokerApp` | Top-level container (App Page, Home Page, Tab) |
| `roomList`, `roomCreation`, `roomDashboard` | Browse, create and manage rooms |
| `estimationSession` | The live session shell |
| `currentStory`, `storyManager` | Show the active story; manage the story backlog |
| `votingPanel`, `pokerCards`, `voteResults` | Card selection, vote submission, revealed results and statistics |
| `teamManagement` | Teams and members |
| `helpPanel` | Contextual help, tours, feedback |
| `realtimeEventHandler`, `soundPlayer` | Event subscription; audio cues |

### Security model

- Controllers run `with sharing`; object and field access is granted through permission sets.
- Three permission sets:

| Permission set | Intended for |
|----------------|--------------|
| `Estimation_Poker_Team_Member` | Join rooms and vote |
| `Estimation_Poker_Facilitator` | Team Member rights plus create and run rooms, manage stories, reveal and finalize |
| `Estimation_Poker_Admin` | Full control of teams, rooms and data |

- Page layouts are provided for the six main objects under `force-app/main/default/layouts`.

## Repository layout

```
force-app/main/default/
  classes/            Apex controllers, services and tests
  lwc/                Lightning Web Components
  objects/            Custom objects, fields and platform events
  customMetadata/     Help_Content__mdt records
  permissionsets/     Admin, Facilitator, Team Member
  layouts/            Page layouts
config/               Scratch org definition
scripts/              Apex and SOQL helper scripts (e.g. help data seeding)
docs/                 Application and marketing overviews
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

1. Assign `Estimation_Poker_Team_Member`, `Estimation_Poker_Facilitator` or `Estimation_Poker_Admin` to users.
2. Optionally seed help content with `sf apex run -f scripts/insert_team_help.apex`.
3. Place the `planningPokerApp` component on a Lightning App Page, Home Page or Tab. The repository does not include an app, tab or FlexiPage definition, so create one in Lightning App Builder.
4. Make sure Platform Events are enabled so live updates reach connected users.

## Development

| Task | Command |
|------|---------|
| Run Apex tests | `sf apex run test --test-level RunLocalTests --result-format human --wait 10` |
| LWC unit tests | `npm run test:unit` |
| LWC coverage | `npm run test:unit:coverage` |
| Lint | `npm run lint` |
| Format | `npm run prettier` |

Husky and lint-staged run Prettier and ESLint on staged files at commit time.

## Typical session flow

1. A team and its members are created (`TeamController`).
2. A facilitator creates a room with a scale and optional timer (`RoomController.createRoom`) and shares the room code.
3. Stories are added singly or in bulk (`StoryController`).
4. The facilitator sets the current story. Members vote (`VotingController.submitVote`), and each vote publishes a `Poker_Vote_Event__e`, so everyone sees who has voted without seeing values.
5. The facilitator reveals votes (`revealVotes`). `EstimationService` calculates average, median, distribution and outliers.
6. The team discusses, re-votes if needed (`resetVotes`), then the facilitator finalizes (`finalizeEstimate`) and moves to the next story.
