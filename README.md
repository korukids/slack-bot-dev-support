# Slack Bot Dev Support

This bot manages the developer support schedule. Its home is the dev-support channel where colleagues raise requests — it posts the daily on-support assignment there alongside the team's own messages, and passively tracks requests there.

## Commands
The bot responds to the following commands when @ mentioned in slack (e.g. `@Developer Support help`).

Commands work in **any channel the bot is a member of**, not just the dev-support channel — invite it to a separate admin/control channel to manage the roster, work-days, and away status without cluttering the public channel. Wherever a command is typed, it manages the single dev-support rotation and replies in that same channel. (Passive request tracking and the daily posts remain confined to the dev-support channel set by `CHANNEL_ID`.)

### list
Lists all the developers currently on the roster

```
12:36 Jake The Human: @Developer Support list
12:36 Developer Support: The current list is @Jake, @Finn, @IceKing, @BMO, @PrincessBubblegum
```

### next
Skips the developer assigned to developer support today. They will be assigned again tomorrow.

```
08:30 Developer Support: @Finn is on dev support today!
08:31 Jake The Human: Oh, Finn is on holiday today!
08:31 Jake The Human: @Developer Support next
08:31 Developer Support: @IceKing is on dev-support
```

### register @user
Adds a new developer to the back of the roster queue.

```
08:31 Jake The Human: @Developer Support register @Prismo
08:31 Developer Support: Thanks for registering @Prismo!
```

### deregister [@user]
Removes you (if no @user provided) or a given developer permanently from the roster.

```
08:31 Jake The Human: @Developer Support deregister @BMO
08:31 Developer Support: @BMO has been deregistered
```

### workdays [@user] [days|reset]
Configures which days a developer is eligible for dev-support. Defaults to Mon-Fri. Days outside the list are skipped automatically by the scheduled assignment and by `next`.

Accepts comma lists (`mon,tue,wed,thu`) or ranges (`mon-thu`). Valid day tokens: `sun mon tue wed thu fri sat`.

```
08:31 Jake The Human: @Developer Support workdays mon-thu
08:31 Developer Support: @Jake's work-days set to: mon, tue, wed, thu

08:32 Jake The Human: @Developer Support workdays
08:32 Developer Support: @Jake works: mon, tue, wed, thu

08:33 Jake The Human: @Developer Support workdays reset
08:33 Developer Support: @Jake's work-days reset to default (mon-fri).
```

### away [@user] until YYYY-MM-DD | clear
Marks a developer as away through (and including) the given date — i.e. the date is the last day of absence; they're eligible again the day after. The scheduled daily assignment and `next` skip away users, and the flag auto-clears once the date has passed.

```
08:31 Jake The Human: @Developer Support away until 2026-06-01
08:31 Developer Support: @Jake marked away until 2026-06-01.

08:32 Jake The Human: @Developer Support away clear
08:32 Developer Support: @Jake is no longer marked away.
```

### assign [me | @user]
Manually assigns yourself or someone else to dev-support for today. The current assignee is displaced to the back of the rotation. Other users keep their place in the cycle — only the displaced assignee loses their turn.

```
10:15 Jake The Human: @Developer Support assign
10:15 Developer Support: @Jake is on dev-support

10:16 Jake The Human: @Developer Support assign @Finn
10:16 Developer Support: @Finn is on dev-support
```

### help
Lists all available commands.

## Request tracking & reminders

Beyond managing the rotation, the bot watches the dev-support channel, keeps an eye on incoming requests, and posts reminders and a daily summary back to the same channel. The bot must be **invited to the channel** (it only receives events for channels it is a member of).

### What counts as a request
Every top-level (non-threaded) message in the channel is tracked as a request. Thread replies, bot messages, and system messages (joins, edits, etc.) are ignored.

### Lifecycle
Each request moves through a lifecycle inferred from the team's existing conventions:

| State | Signal |
| --- | --- |
| **New** | A top-level message arrives. |
| **Investigating** | Someone reacts with :eyes:. |
| **Acknowledged** | Any developer on the roster (not just today's assignee, and not the original poster) replies in the thread. The first such reply wins. |
| **Closed** | Someone reacts with :white_check_mark: or :x: — both simply mean closed. |

Removing a reaction reverts the corresponding state (e.g. removing the :eyes: clears the investigating mark; removing the close reaction reopens the request).

### Scheduled posts
These are driven by Rake tasks (see Scheduling), run on weekdays by an external scheduler. Wording is kept light since these post in the shared channel where colleagues can see them.

- **`assign`** — the daily morning message also lists any requests still open from previous days, so nothing silently rolls over (no carryover when the slate is clean).
- **`support_nudge`** — a mid-day status note listing requests still open or awaiting a first response. Silent if everything is clear.
- **`support_summary`** — an end-of-day wrap-up. Always posts, even on a quiet day. Reports request count, resolved count, what is carrying into tomorrow, and the typical first-response and resolution times.

> Requests are counted in the summary for the day they were **created**. A request opened yesterday and closed today shows as carrying over until it closes, and contributes its timings to yesterday's figures.

Request records are kept for ~90 days and then expire automatically.

## Configuration

The bot reads its configuration from environment variables (see `.env-sample`):

| Variable | Purpose |
| --- | --- |
| `SLACK_API_TOKEN` | Bot token (`xoxb-…`). Used for posting messages and reading the bot's own identity. |
| `SLACK_APP_TOKEN` | App-level token (`xapp-…`, scope `connections:write`). Used to open the Socket Mode connection. |
| `CHANNEL_ID` | The dev-support channel **id** (e.g. `C0123ABC`, not the channel name) the bot posts to. **The bot must be invited to this channel.** |
| `REDIS_URL` | Redis connection (defaults to `redis://localhost:6379/`). |

### Slack app setup

The bot connects over [Socket Mode](https://docs.slack.dev/apps/connecting-to-slack/socket-mode/) (the RTM API it originally used is no longer available to modern apps). Create a Slack app from scratch and configure:

- **Socket Mode** — enable it. Under *Basic Information → App-Level Tokens*, generate a token with the `connections:write` scope → this is `SLACK_APP_TOKEN`.
- **Bot token scopes** (*OAuth & Permissions*): `chat:write`, `channels:history`, `reactions:read`, `app_mentions:read`. Add `groups:history` if the dev-support channel is private. Install to the workspace → the *Bot User OAuth Token* is `SLACK_API_TOKEN`.
- **Event subscriptions** (*Event Subscriptions → Subscribe to bot events*): `message.channels`, `reaction_added`, `reaction_removed`, `app_mention`. (No request URL is needed — Socket Mode delivers these over the WebSocket.)
- **Invite the bot to the dev-support channel.** It only receives events for channels it's a member of.

## Scheduling

Time-based behaviour runs as Rake tasks triggered by an external scheduler (e.g. cron, Heroku Scheduler), on weekdays. Run a task with `bundle exec rake <task>`.

| Task | When | Purpose |
| --- | --- | --- |
| `assign` | 09:00 | Pick today's on-support developer and post the daily message (names the dev, sets expectations, and lists any carryover). |
| `support_nudge` | 11:00 & 15:00 | Mid-day status note. |
| `support_summary` | 17:30 | End-of-day wrap-up. |

## Migrating the roster

The rotation roster is a Redis list keyed by channel: `"<channel-id>_users"`. If you change `CHANNEL_ID` (for example when first moving the bot into the dev-support channel), the roster keyed off the old channel is left behind.

You can either **re-register** everyone in the new channel (`@Developer Support register`), or **carry the existing roster over** by copying the Redis list — run this before or after deploy:

```
# Replace OLD_CHANNEL_ID / NEW_CHANNEL_ID with the real channel ids.
redis-cli COPY OLD_CHANNEL_ID_users NEW_CHANNEL_ID_users        # Redis >= 6.2
# Or, on older Redis without COPY (consumes the old key):
redis-cli RENAME OLD_CHANNEL_ID_users NEW_CHANNEL_ID_users
```

Per-user settings (work-days, away dates) live under `"<channel-id>_user:<user-id>"`. They're light enough to re-enter, or copy them across the same way (`redis-cli --scan --pattern 'OLD_CHANNEL_ID_user:*'`).

## How to develop

### Run locally

1. `bundle install` (Ruby 3.1.2 — see `.ruby-version`).
2. Start Redis: `redis-server` (or `brew services start redis`).
3. Copy `.env-sample` to `.env` and fill in `SLACK_API_TOKEN`, `SLACK_APP_TOKEN`, and `CHANNEL_ID` (see [Slack app setup](#slack-app-setup)).
4. `bundle exec rackup` — boots the Socket Mode bot on a background thread alongside the Sinatra web process.

Because every command and scheduled task posts into the live `CHANNEL_ID`, point a **separate test app + channel** at your local run rather than reusing the production bot — reusing the production token runs a second copy of the bot that double-processes events and corrupts the rotation. To exercise the scheduled posts on demand, run the Rake tasks directly: `bundle exec rake assign` / `support_nudge` / `support_summary`.

### Test
run `rspec` to run tests in the project