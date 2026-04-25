# bt-cert-system

A certification system for fivem qb-core servers. lets supervisors issue and revoke job certifications to players, and can restrict access to specific garages based on whether a player holds a cert. everything is saved to a database and synced in real time.

---

## Dependencies

all of these are required

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [jg-advancedgarages](https://github.com/JonasDev17/jg-advancedgarages) (only needed if you want garage access control)

---

## install

1. drop the folder into your resources
   ```
   resources/[scripts]/bt-cert-system
   ```

2. import the sql file into your database
   ```
   cert_system.sql
   ```

3. add to server.cfg
   ```
   ensure bt-cert-system
   ```

4. configure config.lua

---

## database

the script creates one table: `player_certs`

| column | type | info |
|---|---|---|
| id | int | auto increment pk |
| citizenid | varchar | player character id |
| cert_name | varchar | name of the cert |
| given_by | varchar | who issued it |
| given_at | timestamp | when it was issued |

players cant hold duplicate certs, theres a unique constraint on citizenid + cert_name.

---

## configuration

everything is in config.lua

### certs

define what certs exist and who can give/manage them:

```lua
Config.Certs = {
    ['police_hwy'] = {
        label = 'Highway Certification',
        description = 'Allows access to highway garage',
        givers = { ['police'] = 6 },   -- job and minimum grade to issue this cert
        managers = { ['police'] = 6 }, -- job and minimum grade to revoke this cert
    },
}
```

- `givers` - who can issue the cert. key is job name, value is minimum grade level
- `managers` - who can revoke the cert. same format

### garage requirements

restrict garages so only players with a specific cert can access them:

```lua
Config.GarageRequirements = {
    ['Police_hwy'] = {
        job = 'police',    -- player must have this job
        cert = 'police_hwy', -- and this cert (unless they meet minGrade)
        minGrade = 5,      -- players at or above this grade skip the cert check
    },
}
```

the garage id needs to match the id used by jg-advancedgarages.

---

## usage

### in game commands

**`/certmenu`** or press **F6**
opens the cert management menu. only shows certs you have permission to give or manage.

from the menu you can:
- issue a cert to a nearby player (must be within 5m)
- view all players who hold a cert
- revoke a cert from a player

### admin commands

these require ACE permissions and can be run from the server console or in-game

**`/givecert <serverid> <certname>`**
gives a cert to a player by their server id

**`/revokecert <serverid> <certname>`**
removes a cert from a player by their server id

example:
```
/givecert 5 police_hwy
/revokecert 5 police_hwy
```

---

## how it works

**issuing a cert**
1. open `/certmenu`, select the cert, then select "Issue Cert"
2. nearby players within 5m show up as options
3. select the player, server validates your grade, inserts into db and syncs both players

**revoking a cert**
1. open `/certmenu`, select the cert, then select "Revoke Cert"
2. a list of all current holders pulls from the db
3. select a player and confirm, server removes it from db and syncs the target if theyre online

**garage access**
when a player tries to open a configured garage the script checks:
1. does the player have the right job? if not, denied
2. is the player at or above minGrade? if yes, allowed (no cert needed)
3. does the player have the required cert? if yes, allowed, otherwise denied

---

## exports

### client

**`localPlayerHasCert(certName)`** - returns true/false, checks if the local player has a cert

**`localPlayerCanAccessGarage(garageId)`** - returns true/false, checks if player meets garage requirements

### server

**`playerHasCert(source, certName)`** - returns true/false, checks if a player has a cert

**`canAccessJobGarage(source, garageId)`** - returns true/false, checks if player can access a garage

---

## files

```
bt-cert-system/
├── fxmanifest.lua
├── config.lua
├── cert_system.sql
├── client/
│   └── main.lua
└── server/
    └── main.lua
```

---

free to use, do whatever with it
