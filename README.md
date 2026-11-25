# Kakhulu Kakhulu

A 3D Roblox obby (obstacle course). A grey baseplate, a 3x3 difficulty
board near spawn, and nine stages of increasing difficulty running off
into the distance:

1. Easy
2. Medium
3. Hard
4. Difficult
5. Way Dificil
6. Extra Difficult
7. Bridge to Insanity
8. Mental
9. YNNACNU

Five hidden secrets scattered around the map award real Roblox badges
when found. One of them, "Pixelation" (rated Bridge to Insanity), isn't
something you walk into at all -- it's a single tiny black pixel hidden
somewhere up in the sky, and you have to actually spot it and click it.

This is a scripted project, not a `.rbxl` file -- the whole map (baseplate,
board, all nine stages, checkpoints, hazards, secrets) is **built by a
script at server startup**, not hand-placed. That's deliberate: it means
the entire level lives in version control as readable code, and it's
trivial to retune (change a gap distance, a platform size, a hazard type)
without digging through hundreds of hand-placed parts in Studio.

## What's here

```
src/ServerScriptService/
  MapBuilder.server.lua        -- builds the baseplate, board, all 9 stages, secrets
  CheckpointHandler.server.lua -- respawn-at-last-checkpoint logic
  SecretBadges.server.lua      -- awards a Roblox Badge per secret found
default.project.json           -- Rojo project file
```

## Getting it into Roblox Studio

**If you use [Rojo](https://rojo.space/):**

```
rojo serve
```

then connect to it from the Rojo plugin inside Studio in a new/existing
place, and the three scripts will sync into `ServerScriptService`
automatically.

**If you don't use Rojo:** it's three plain scripts, so just copy them in
by hand:

1. Open Roblox Studio, create (or open) a place.
2. In the Explorer, right-click **ServerScriptService** -> Insert Object
   -> **Script**, and do this three times, naming them `MapBuilder`,
   `CheckpointHandler`, and `SecretBadges`.
3. Open each file under `src/ServerScriptService/` in this repo and paste
   its contents into the matching Script.
4. Press **Play**. The map builds itself the moment the server starts.

## Setting up the 5 secret badges

`SecretBadges.server.lua` can't create real Roblox Badges for you --
that has to happen on Roblox's own site, tied to your actual game:

1. Publish the place at least once (badges need a real game/universe to
   belong to).
2. Go to the [Creator Dashboard](https://create.roblox.com/dashboard) ->
   your experience -> **Badges** -> **Create a Badge**. Do this 5 times
   (one per secret), with whatever names/icons/descriptions you want.
3. Each badge's numeric ID is shown on its page. Paste the 5 IDs into
   `SECRET_BADGE_IDS` at the top of `SecretBadges.server.lua`, replacing
   the `0` placeholders.
4. In Studio, turn on **Enable Studio Access to API Services** (Home tab
   -> Game Settings -> Security) so BadgeService calls work while
   playtesting, not just once actually published.

Until real IDs are in place, finding a secret just prints a warning in
the server output instead of silently pretending to award a badge that
doesn't exist.

## About the secret placements

Secrets 2 through 5 in `MapBuilder.server.lua` (a detour off Easy, a
ground-level spot below where the course has climbed overhead, another
ground-level detour past the harder middle stretch, and a small jump off
to the side right near the end) are a starting point, not a finished
puzzle design -- there's no way to verify from outside Studio whether a
given spot actually *reads* as hidden-but-findable once you can see and
move through the real 3D space. Once you're in there, feel free to
relocate or better-disguise any of them (behind a wall, inside a prop,
under a trapdoor) while keeping each part's `Secret<N>` CollectionService
tag so `SecretBadges.server.lua` still finds it.

Secret 1, "Pixelation," works differently: it's a non-collidable 0.4-stud
black part placed at a random spot high in the sky (`buildSkyPixelSecret`
in `MapBuilder.server.lua`), picked up by a `ClickDetector` instead of
`Touched` since there's nothing to walk into. Its exact spot re-rolls
every time the map rebuilds (every server start) -- if that's not what
you want (e.g. you'd rather it sit at one fixed, chosen spot), swap the
three `math.random(...)` calls in `buildSkyPixelSecret` for fixed
numbers. Same caveat as the others: whether a 0.4-stud dot is actually
findable-but-not-impossible against the real default sky can only be
judged by eye in Studio.

## Tuning the course

Every stage's shape comes from one table at the top of
`MapBuilder.server.lua`:

```lua
local DIFFICULTIES = {
  { name = "EASY", color = ..., platformSize = 6, gap = 4, count = 6, hazard = "none" },
  ...
}
```

`platformSize` shrinks and `gap` grows as the tiers get harder;
`hazard` picks which behavior applies (`none`, `slowMover`, `fastMover`,
`disappear`, `spinner`, `narrowBridge`, `strobe`, `chaos` -- see
`applyHazard()`). Add a hazard type, change a count, or reorder the
table and the whole course regenerates accordingly next Play.

## Known limitations

This was built and reviewed as code only -- there's no Roblox Studio
available in the environment it was written in, so none of this has
been visually playtested yet. Expect to need a pass in Studio for things
like exact jump distances feeling right, hazard timings, and whether the
secrets are actually find-able. The Lua API usage (BadgeService,
CollectionService, TweenService, checkpoint/respawn flow) follows the
documented, current Roblox APIs, but "compiles" isn't the same as
"plays well" for a course like this.
