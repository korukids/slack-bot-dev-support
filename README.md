# Slack Bot Dev Support

This bot manages the developer support schedule.

## Commands
The bot responds to the following commands when @ mentioned in slack (e.g. `@Developer Support help`)

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

## How to develop

### Test
run `rspec` to run tests in the project