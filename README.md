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

### help
Lists all available commands.

## How to develop

### Test
run `rspec` to run tests in the project