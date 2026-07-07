"""Superhero Mode (Ages 3-5) — villain/problem/power compatibility matrix.

This module is a pure-data file plus a small selector. It is consumed by
the superhero prompt builder when ``theme == 'superhero'``. Keeping the
matrix here (instead of inside the prompt service) lets us unit-test the
pairing logic in isolation and lets the frontend hit a thin endpoint
later if we ever want to surface the catalogue to clients.

Design rules:
- Every power has ONE ideal villain (best narrative fit) plus 4-5 "also-works"
  options so we don't repeat the same hero-vs-villain pair every session.
- Every villain advertises 3 compatible problem types. The selector
  intersects the power's available villains with each villain's problem
  list to ensure the chosen (villain, problem) pair is always sensible.
- All resolution verbs are non-violent: tidy, cheer, share, comfort,
  invite, calm, find, repair. Villains soften / say sorry / join in —
  never get defeated. This is a Sprout-band (ages 3-5) story chain.
"""

from __future__ import annotations

import random
from typing import Iterable

# ---------------------------------------------------------------------------
# Villains — silly, never frightening. The ``action`` phrase is dropped into
# Beat 2 of the 6-beat chain ("Oh no! [Villain] came to [villain-action].").
# ---------------------------------------------------------------------------
VILLAINS: dict[str, dict] = {
    "mess_monster": {
        "name": "Mess Monster",
        "action": "scatters crumbs and toys everywhere",
        "softens": "smiled and helped tidy up",
    },
    "grumpy_cloud": {
        "name": "Grumpy Cloud",
        "action": "rains on picnics until cheered up",
        "softens": "turned pink and floated away happy",
    },
    "sock_goblin": {
        "name": "Sock Goblin",
        "action": "steals one sock from every pair",
        "softens": "giggled and gave the socks back",
    },
    "no_share_shark": {
        "name": "No-Share Shark",
        "action": "won't share the slide, swing, or snack",
        "softens": "said sorry and took turns",
    },
    "bedtime_bandit": {
        "name": "Bedtime Bandit",
        "action": "hides bedtime stories and stuffed animals",
        "softens": "tiptoed back with everything safe",
    },
    "noise_beast": {
        "name": "Noise Beast",
        "action": "roars too loud and scares baby animals",
        "softens": "whispered a tiny, kind hello",
    },
    "sticky_mcgoo": {
        "name": "Sticky McGoo",
        "action": "gets jam and goo on everything",
        "softens": "said sorry and helped wipe it clean",
    },
    "the_frownerator": {
        "name": "The Frownerator",
        "action": "collects smiles in a jar",
        "softens": "smiled too and let the smiles go free",
    },
    "lost_things_sprite": {
        "name": "Lost-Things Sprite",
        "action": "moves toys so kids can't find them",
        "softens": "fluttered close and showed where they were",
    },
    "cranky_crab": {
        "name": "Cranky Crab",
        # Phrased as a verb-phrase so Beat 2 reads naturally: "came to {action}".
        # The "short-tempered but secretly lonely" backstory is communicated
        # via the "softens" beat instead.
        "action": "snap at everyone on the beach",
        "softens": "smiled — really, the crab was just lonely — and joined the fun",
    },
}

# ---------------------------------------------------------------------------
# Problems — the *goal* the hero pursues during beats 3-5. ``verb`` is the
# child-friendly action verb the prompt asks the model to use.
# ---------------------------------------------------------------------------
PROBLEMS: dict[str, dict] = {
    "get_back": {
        "name": "Get it back",
        "verb": "find and return",
        "summary": "return a taken object",
    },
    "clean_up": {
        "name": "Clean up",
        "verb": "tidy",
        "summary": "tidy what was scattered",
    },
    "cheer_up": {
        "name": "Cheer up",
        "verb": "cheer up",
        "summary": "restore joy to a sad friend",
    },
    "make_peace": {
        "name": "Make peace",
        "verb": "calm",
        "summary": "calm a cranky character",
    },
    "share_fairly": {
        "name": "Share fairly",
        "verb": "share",
        "summary": "split a snack or turn",
    },
    "quiet_down": {
        "name": "Quiet down",
        "verb": "gentle",
        "summary": "gentle the loud",
    },
    "find_friend": {
        "name": "Find a friend",
        "verb": "search for",
        "summary": "search and rescue",
    },
    "comfort_scared": {
        "name": "Comfort the scared",
        "verb": "comfort",
        "summary": "soothe fears",
    },
    "include_left_out": {
        "name": "Include the left-out",
        "verb": "invite in",
        "summary": "invite someone in",
    },
    "help_say_sorry": {
        "name": "Help say sorry",
        "verb": "help repair",
        "summary": "model repair",
    },
}

# ---------------------------------------------------------------------------
# Powers — the hero's signature super-ability. The ``verb`` is the action
# verb used in Beat 4 ("[Name] used [power-verb] to [problem-action].").
# ``ideal`` is the single most thematic villain match; ``also`` lists the
# other villains the power can credibly pair with. ``primary_problem`` is
# a sensible default if a frontend chooses to skip random pairing.
# ---------------------------------------------------------------------------
POWERS: dict[str, dict] = {
    "super_speed": {
        "name": "Super Speed",
        "verb": "zoom",
        "ideal": "sock_goblin",
        "also": [
            "lost_things_sprite",
            "mess_monster",
            "bedtime_bandit",
            "sticky_mcgoo",
        ],
        "primary_problem": "get_back",
    },
    "flying": {
        "name": "Flying",
        "verb": "fly up",
        "ideal": "grumpy_cloud",
        "also": ["noise_beast", "lost_things_sprite", "the_frownerator", "sock_goblin"],
        "primary_problem": "cheer_up",
    },
    "super_strength": {
        "name": "Super Strength",
        "verb": "lift",
        "ideal": "mess_monster",
        "also": ["sticky_mcgoo", "lost_things_sprite", "bedtime_bandit", "sock_goblin"],
        "primary_problem": "clean_up",
    },
    "super_hearing": {
        "name": "Super Hearing",
        "verb": "listen carefully",
        "ideal": "lost_things_sprite",
        "also": ["sock_goblin", "bedtime_bandit", "sticky_mcgoo", "the_frownerator"],
        "primary_problem": "find_friend",
    },
    "super_smile": {
        "name": "Super Smile",
        "verb": "smile big",
        "ideal": "the_frownerator",
        "also": ["grumpy_cloud", "cranky_crab", "no_share_shark", "noise_beast"],
        "primary_problem": "cheer_up",
    },
    "super_hugs": {
        "name": "Super Hugs",
        "verb": "give a warm hug",
        "ideal": "cranky_crab",
        "also": ["grumpy_cloud", "the_frownerator", "no_share_shark", "bedtime_bandit"],
        "primary_problem": "make_peace",
    },
    "super_whisper": {
        "name": "Super Whisper",
        "verb": "whisper softly",
        "ideal": "noise_beast",
        "also": ["cranky_crab", "grumpy_cloud", "the_frownerator", "bedtime_bandit"],
        "primary_problem": "quiet_down",
    },
    "super_sharing": {
        "name": "Super Sharing",
        "verb": "share",
        "ideal": "no_share_shark",
        "also": ["sticky_mcgoo", "cranky_crab", "mess_monster", "sock_goblin"],
        "primary_problem": "share_fairly",
    },
}

# ---------------------------------------------------------------------------
# Villain -> sensible problem types. Used both to validate pairings and to
# pick a problem given a chosen villain.
# ---------------------------------------------------------------------------
VILLAIN_PROBLEMS: dict[str, list[str]] = {
    "mess_monster": ["clean_up", "share_fairly", "get_back"],
    "grumpy_cloud": ["cheer_up", "make_peace", "comfort_scared"],
    "sock_goblin": ["get_back", "find_friend", "share_fairly"],
    "no_share_shark": ["share_fairly", "make_peace", "include_left_out"],
    "bedtime_bandit": ["get_back", "comfort_scared", "find_friend"],
    "noise_beast": ["quiet_down", "make_peace", "comfort_scared"],
    "sticky_mcgoo": ["clean_up", "help_say_sorry", "get_back"],
    "the_frownerator": ["cheer_up", "get_back", "help_say_sorry"],
    "lost_things_sprite": ["find_friend", "get_back", "help_say_sorry"],
    "cranky_crab": ["make_peace", "include_left_out", "cheer_up"],
}


# ---------------------------------------------------------------------------
# Explorer-band (ages 6-8) matrix — parallel to the Sprout tables above.
# Villains are mischief-makers with motives a 6-8-year-old can decode
# (lonely, curious, misunderstood); never frightening. Problems include
# actual puzzle/agency verbs (decode, see-through, bridge) on top of the
# kindness-based ones. All resolutions still come through empathy,
# cleverness, sharing, or inviting in — never force.
# ---------------------------------------------------------------------------
EXPLORER_VILLAINS: dict[str, dict] = {
    "shadow_trickster": {
        "name": "the Shadow Trickster",
        "action": "copy everyone's moves to confuse them",
        "softens": "stopped hiding once someone finally noticed them — they were just lonely",
    },
    "forgetting_fog": {
        "name": "the Forgetting Fog",
        "action": "drift through town making important things slip from memory",
        "softens": "thinned out once it understood what it was doing and rolled away gently",
    },
    "tangle_knot_twins": {
        "name": "the Tangle-Knot Twins",
        "action": "twist ropes, laces, and headphones into giggly knots",
        "softens": "untied everything and asked to learn a new game instead",
    },
    "echo_bandit": {
        "name": "the Echo Bandit",
        "action": "snatch important sounds — the school bell, a friend's laugh — into a bottle",
        "softens": "uncorked the bottle and gave every sound back",
    },
    "the_grumblestorm": {
        "name": "the Grumblestorm",
        "action": "follow one person around like a tiny cranky thundercloud",
        "softens": "turned soft pink once someone helped it name what was bothering it",
    },
    "glitchworm": {
        "name": "the Glitchworm",
        "action": "wriggle into screens and scramble pictures and words",
        "softens": "blinked, said sorry, and slithered off to learn how things work",
    },
    "wishing_thief": {
        "name": "the Wishing Thief",
        "action": "scoop up wishes from fountains without asking",
        "softens": "poured every wish back and asked permission next time",
    },
    "captain_boast": {
        "name": "Captain Boast",
        "action": "puff up so big that everyone else feels small",
        "softens": "got a little quieter and admitted they just wanted to be seen too",
    },
}

EXPLORER_PROBLEMS: dict[str, dict] = {
    "find_missing_piece": {
        "name": "Find the missing piece",
        "verb": "search for and recover",
        "summary": "track down what's gone missing",
    },
    "decode_signal": {
        "name": "Decode the signal",
        "verb": "figure out",
        "summary": "read a clue or message",
    },
    "calm_the_storm": {
        "name": "Calm the storm",
        "verb": "settle",
        "summary": "help a big feeling cool down",
    },
    "restore_what_taken": {
        "name": "Restore what was taken",
        "verb": "return and mend",
        "summary": "give back what was taken and patch what broke",
    },
    "bridge_the_divide": {
        "name": "Bridge the divide",
        "verb": "bring together",
        "summary": "help two sides understand each other",
    },
    "see_through_trick": {
        "name": "See through the trick",
        "verb": "notice",
        "summary": "spot what's really going on",
    },
    "light_the_way": {
        "name": "Light the way",
        "verb": "guide",
        "summary": "help someone find their courage or direction",
    },
    "trade_fair": {
        "name": "Make a fair trade",
        "verb": "swap fairly",
        "summary": "find a deal where everyone wins",
    },
}

# Explorer powers reuse the 8 Sprout IDs (so existing frontend pickers keep
# working) but with Explorer-tier display names and verbs, plus 2 Explorer-
# only powers (feeling_sense, invisibility).
EXPLORER_POWERS: dict[str, dict] = {
    "super_speed": {
        "name": "Lightning Speed",
        "verb": "dash",
        "ideal": "tangle_knot_twins",
        "also": ["forgetting_fog", "echo_bandit", "glitchworm", "captain_boast"],
        "primary_problem": "restore_what_taken",
    },
    "flying": {
        "name": "Sky Glide",
        "verb": "glide up",
        "ideal": "the_grumblestorm",
        "also": ["echo_bandit", "forgetting_fog", "shadow_trickster", "wishing_thief"],
        "primary_problem": "calm_the_storm",
    },
    "super_strength": {
        "name": "Strong Lift",
        "verb": "lift gently",
        "ideal": "tangle_knot_twins",
        "also": ["wishing_thief", "echo_bandit", "glitchworm", "captain_boast"],
        "primary_problem": "restore_what_taken",
    },
    "super_hearing": {
        "name": "Keen Ears",
        "verb": "listen close",
        "ideal": "echo_bandit",
        "also": [
            "glitchworm",
            "shadow_trickster",
            "forgetting_fog",
            "the_grumblestorm",
        ],
        "primary_problem": "decode_signal",
    },
    "super_smile": {
        "name": "Bright Smile",
        "verb": "beam bright",
        "ideal": "the_grumblestorm",
        "also": [
            "captain_boast",
            "shadow_trickster",
            "wishing_thief",
            "forgetting_fog",
        ],
        "primary_problem": "calm_the_storm",
    },
    "super_hugs": {
        "name": "Big Heart Hug",
        "verb": "hug warmly",
        "ideal": "captain_boast",
        "also": [
            "the_grumblestorm",
            "shadow_trickster",
            "forgetting_fog",
            "wishing_thief",
        ],
        "primary_problem": "bridge_the_divide",
    },
    "super_whisper": {
        "name": "Quiet Voice",
        "verb": "speak quietly",
        "ideal": "the_grumblestorm",
        "also": ["captain_boast", "glitchworm", "shadow_trickster", "echo_bandit"],
        "primary_problem": "calm_the_storm",
    },
    "super_sharing": {
        "name": "Fair Share",
        "verb": "share fairly",
        "ideal": "wishing_thief",
        "also": ["captain_boast", "tangle_knot_twins", "echo_bandit", "glitchworm"],
        "primary_problem": "trade_fair",
    },
    # Explorer-only powers — frontend exposes these only when band==explorer.
    "feeling_sense": {
        "name": "Feeling Sense",
        "verb": "sense what they feel",
        "ideal": "shadow_trickster",
        "also": ["captain_boast", "the_grumblestorm", "echo_bandit", "wishing_thief"],
        "primary_problem": "see_through_trick",
    },
    "invisibility": {
        "name": "Soft Step",
        "verb": "move unseen",
        "ideal": "captain_boast",
        "also": ["shadow_trickster", "glitchworm", "forgetting_fog", "echo_bandit"],
        "primary_problem": "see_through_trick",
    },
}

EXPLORER_VILLAIN_PROBLEMS: dict[str, list[str]] = {
    "shadow_trickster": ["see_through_trick", "light_the_way", "find_missing_piece"],
    "forgetting_fog": ["find_missing_piece", "decode_signal", "light_the_way"],
    "tangle_knot_twins": ["restore_what_taken", "trade_fair", "bridge_the_divide"],
    "echo_bandit": ["restore_what_taken", "decode_signal", "find_missing_piece"],
    "the_grumblestorm": ["calm_the_storm", "bridge_the_divide", "light_the_way"],
    "glitchworm": ["decode_signal", "see_through_trick", "restore_what_taken"],
    "wishing_thief": ["restore_what_taken", "trade_fair", "light_the_way"],
    "captain_boast": ["bridge_the_divide", "see_through_trick", "light_the_way"],
}


# ---------------------------------------------------------------------------
# Adventurer-band (ages 9-12) matrix — parallel to the Sprout/Explorer tables.
# These villains are FUNNY on the surface and REAL underneath: a gross-goofy or
# gadget-mad premise a tween instantly loves, wrapped around a genuine,
# relatable need (loneliness, perfectionism, feeling invisible or left out).
# Each carries four story-shaping fields beyond name/action:
#   - ``personality``: how they talk and behave (voice for the model).
#   - ``backstory``: the real need under the trouble — revealed gradually so the
#     reader ends up understanding them.
#   - ``weakness``: a RIDICULOUS, non-violent vulnerability the hero exploits
#     with cleverness, not force (asking a question, a peanut-butter jar, a
#     spotlight) — this is the engine of the "out-think, never fight" win.
#   - ``softens``: a *changed mind / met need*, never "defeated".
# Resolution ALWAYS comes through cleverness, courage, empathy, and meeting the
# real need — NEVER violence, weapons, fighting, or fear.
# ---------------------------------------------------------------------------
ADVENTURER_VILLAINS: dict[str, dict] = {
    "gigawatt": {
        "name": "Gigawatt",
        "action": "wire the whole town with 'helpful' gadgets that take over every chore and decision",
        "personality": "a motor-mouthed boy-genius inventor who talks in exclamation points, never sits still, and cannot resist explaining how every gadget works",
        "backstory": "Gigawatt was always told they were 'too much,' so they build machines to be so useful that people will finally want them around — the real need is to be valued for who they are, not just what they build",
        "weakness": "every gadget runs off one absurdly tangled extension cord, and a genuine question about an invention sends Gigawatt into such an excited explanation that the whole scheme grinds to a halt",
        "softens": "powered down the takeover once the hero showed the town wanted Gigawatt, not just the gadgets, and invited them to build something together",
    },
    "lord_loading_screen": {
        "name": "Lord Loading Screen",
        "action": "make every door, lesson, and game stall and buffer so nothing in town ever quite finishes",
        "personality": "a slow, sighing perfectionist in a spinning-wheel cloak who insists everything needs 'just a moment longer' to be perfect",
        "backstory": "Lord Loading Screen is terrified of getting things wrong, so he freezes the moment before anything finishes — if it never finishes, it can never be a mistake; the real need is to learn that 'done' is braver than 'perfect'",
        "weakness": "he panics whenever someone reaches for a 'skip' button, and he cannot resist finishing a countdown out loud once it has started",
        "softens": "let the town start moving again once the hero showed him that finishing something imperfect is how anything good ever gets made",
    },
    "doctor_detention": {
        "name": "Doctor Detention",
        "action": "freeze every clock so the school bell never rings and the day never ends",
        "personality": "a brisk, rule-quoting hall-monitor of a villain who hands out tidy yellow slips and secretly hums to themselves when no one is looking",
        "backstory": "Doctor Detention keeps school open forever because the busy hallways feel safer and less lonely than an empty house after the bell; the real need is a place to belong once the day is over",
        "weakness": "they cannot ignore a politely raised hand or a sincere question, and the smell of cafeteria pizza makes them lose track of every rule",
        "softens": "let the final bell ring once the hero helped them find a club and friends to go home to, so the empty afternoons weren't lonely anymore",
    },
    "mister_meh": {
        "name": "Mister Meh",
        "action": "drain the excitement out of birthdays, games, and even superpowers until everything feels gray and boring",
        "personality": "a flat, shrugging villain in head-to-toe beige who answers every wonder with 'eh, whatever' and a long, tired sigh",
        "backstory": "Mister Meh was never once allowed to play or make a mess, so joy started to feel unfair — if he can't have fun, it is easier if no one does; the real need is permission to be delighted again",
        "weakness": "a single genuine belly-laugh nearby cracks his gray haze, and he absolutely cannot keep a straight face around a really good (or really terrible) pun",
        "softens": "let the color and fun rush back once the hero invited him into the game and showed him it was finally his turn to play",
    },
    "booger_baron": {
        "name": "the Booger Baron",
        "action": "fling sticky green goo and send a swarm of nose-shaped drones to keep everyone at arm's length",
        "personality": "a theatrical, sniffly villain who calls everyone 'darling,' bows far too much, and is weirdly proud of how gross he is",
        "backstory": "the Booger Baron grosses people out on purpose so they leave first — that way they can never reject him up close; the real need is to learn that a true friend won't be scared off",
        "weakness": "he is helplessly ticklish, and a single offered tissue or a kind 'bless you' so surprises him that his whole goo-machine sputters out",
        "softens": "wiped up the goo and called off the drones once the hero stayed anyway and offered to be his friend without flinching",
    },
    "llama_of_doom": {
        "name": "the Llama of Doom",
        "action": "stage enormous dramatic scenes and demand that all of llama-kind finally be crowned rulers of the town",
        "personality": "a gloriously over-the-top drama-llama in a swishy cape who gasps, faints onto fainting-couches, and narrates their own villainy out loud",
        "backstory": "the Llama of Doom feels completely invisible unless they are making a giant scene, so the bigger the drama, the more they feel seen; the real need is to matter to someone without having to perform",
        "weakness": "they cannot resist an audience, a spotlight, or a round of applause — point a camera or ask for an encore and the whole evil plan turns into a one-llama show",
        "softens": "took a bow and dropped the doom once the hero gave them a real role on the festival stage and a friend who would watch even the quiet moments",
    },
    "professor_picklejuice": {
        "name": "Professor Picklejuice",
        "action": "fire sour-pickle blasts and sweep every snack in town into a giant brine-filled vault",
        "personality": "a giggling, briny mad-scientist who wears swim goggles, smells intensely of vinegar, and has named every single pickle in the lab",
        "backstory": "Professor Picklejuice hoards snacks because they were never picked for a team or invited to a party — a full pantry feels like never being left out again; the real need is a seat at the table",
        "weakness": "a single jar of peanut butter completely scrambles their sour-powers, and they cannot turn down a genuine invitation to share a snack",
        "softens": "unsealed the brine vault and handed the snacks back once the hero saved them a seat and a plate at the town picnic",
    },
    "count_copypaste": {
        "name": "Count Copy-Paste",
        "action": "spin out dozens of slightly-wrong copies of himself that crowd the town and argue over who is the real one",
        "personality": "a flustered, formal count who keeps insisting 'I am the original!' while his copies bicker, finish his sentences, and contradict him",
        "backstory": "Count Copy-Paste makes copy after copy hoping one of them will finally be 'good enough,' because he is sure the real him is not; the real need is to believe the first, imperfect original was worthy all along",
        "weakness": "the copies cannot agree on anything, so one honest compliment aimed at the REAL Count makes every duplicate freeze in confusion",
        "softens": "let the copies fade once the hero convinced him the first, imperfect original was the one worth keeping all along",
    },
    "the_overlooked": {
        "name": "the Overlooked",
        "action": "sabotage the great festival because no one ever once chose them to lead",
        "personality": "a quiet, watchful figure who lingers at the edge of every crowd, quick to point out that nobody noticed they were even there",
        "backstory": "the Overlooked has been passed over for every team, role, and spotlight, and decided that if they can't be seen for doing good, they'll be seen for this; the real need is to have their real talent finally recognized",
        "weakness": "they melt the instant someone remembers a small kind thing they once did, and they can't keep up the act when sincerely asked for help",
        "softens": "stood down the moment the hero made sure their real talent was finally seen",
    },
    "the_gatekeeper": {
        "name": "the Gatekeeper",
        "action": "wall off the old quarter to keep every outsider away after being hurt once",
        "personality": "a gruff, watchful guardian rattling a huge ring of keys — polite but immovable, certain that every gate is safer shut",
        "backstory": "the Gatekeeper was hurt badly the last time they let someone in, so now they lock every door to make sure it can never happen again; the real need is to feel safe enough to belong again",
        "weakness": "they cannot bring themselves to lock a gate against someone clearly in real trouble, and a shared cup of tea undoes their sternest rule",
        "softens": "opened the gate after the hero showed them they still belonged",
    },
}

ADVENTURER_PROBLEMS: dict[str, dict] = {
    "uncover_the_truth": {
        "name": "Uncover the truth",
        "verb": "uncover",
        "summary": "figure out what is really going on beneath the surface",
    },
    "broker_a_truce": {
        "name": "Broker a truce",
        "verb": "negotiate",
        "summary": "get two sides to a fair agreement",
    },
    "rally_the_allies": {
        "name": "Rally the allies",
        "verb": "rally",
        "summary": "bring people together to act as one",
    },
    "outsmart_the_trap": {
        "name": "Outsmart the trap",
        "verb": "out-think",
        "summary": "solve a clever obstacle without force",
    },
    "return_what_was_taken": {
        "name": "Return what was taken",
        "verb": "recover and restore",
        "summary": "give back what was taken and repair the harm",
    },
    "earn_their_trust": {
        "name": "Earn their trust",
        "verb": "win over",
        "summary": "reach someone who has put their guard up",
    },
    "expose_the_real_danger": {
        "name": "Expose the real danger",
        "verb": "reveal",
        "summary": "make everyone see a threat they have ignored",
    },
    "find_the_fair_path": {
        "name": "Find the fair path",
        "verb": "find a fair solution for",
        "summary": "balance two needs that both genuinely matter",
    },
    "give_them_a_voice": {
        "name": "Give them a voice",
        "verb": "speak up for",
        "summary": "make sure the overlooked are finally heard",
    },
    "mend_what_broke": {
        "name": "Mend what broke",
        "verb": "mend",
        "summary": "repair a friendship or a trust that cracked",
    },
}

# Adventurer powers reuse the 8 base IDs (so existing frontend pickers keep
# working) with Adventurer-tier names/verbs, plus 2 Adventurer-only powers
# (strategist, gadgeteer) that fit a 9-12-year-old's fantasies. Powers win the
# day through cleverness and heart, never force.
ADVENTURER_POWERS: dict[str, dict] = {
    "super_speed": {
        "name": "Velocity",
        "verb": "blur into motion",
        "ideal": "count_copypaste",
        "also": [
            "gigawatt",
            "professor_picklejuice",
            "booger_baron",
            "lord_loading_screen",
        ],
        "primary_problem": "return_what_was_taken",
    },
    "flying": {
        "name": "Skyborne",
        "verb": "rise above it all",
        "ideal": "llama_of_doom",
        "also": [
            "booger_baron",
            "gigawatt",
            "doctor_detention",
            "the_gatekeeper",
        ],
        "primary_problem": "expose_the_real_danger",
    },
    "super_strength": {
        "name": "Titan Strength",
        "verb": "haul aside what blocks the way",
        "ideal": "the_gatekeeper",
        "also": [
            "gigawatt",
            "booger_baron",
            "professor_picklejuice",
            "lord_loading_screen",
        ],
        "primary_problem": "outsmart_the_trap",
    },
    "super_hearing": {
        "name": "Echo Sense",
        "verb": "tune in to the faintest sound",
        "ideal": "the_overlooked",
        "also": [
            "count_copypaste",
            "doctor_detention",
            "mister_meh",
            "the_gatekeeper",
        ],
        "primary_problem": "uncover_the_truth",
    },
    "super_smile": {
        "name": "Disarming Charm",
        "verb": "win them over",
        "ideal": "mister_meh",
        "also": [
            "llama_of_doom",
            "the_overlooked",
            "booger_baron",
            "professor_picklejuice",
        ],
        "primary_problem": "give_them_a_voice",
    },
    "super_hugs": {
        "name": "Steadfast Heart",
        "verb": "stand beside them",
        "ideal": "booger_baron",
        "also": [
            "the_gatekeeper",
            "the_overlooked",
            "mister_meh",
            "doctor_detention",
        ],
        "primary_problem": "earn_their_trust",
    },
    "super_whisper": {
        "name": "Calm Voice",
        "verb": "speak low and steady",
        "ideal": "lord_loading_screen",
        "also": [
            "gigawatt",
            "count_copypaste",
            "the_gatekeeper",
            "mister_meh",
        ],
        "primary_problem": "mend_what_broke",
    },
    "super_sharing": {
        "name": "Fair Hand",
        "verb": "share it out fairly",
        "ideal": "professor_picklejuice",
        "also": [
            "gigawatt",
            "count_copypaste",
            "doctor_detention",
            "the_overlooked",
        ],
        "primary_problem": "find_the_fair_path",
    },
    # Adventurer-only powers — frontend exposes these only when band==adventurer.
    "strategist": {
        "name": "Master Strategist",
        "verb": "out-plan the whole scheme",
        "ideal": "gigawatt",
        "also": [
            "lord_loading_screen",
            "count_copypaste",
            "doctor_detention",
            "llama_of_doom",
        ],
        "primary_problem": "outsmart_the_trap",
    },
    "gadgeteer": {
        "name": "Gadgeteer",
        "verb": "rig a clever gadget",
        "ideal": "doctor_detention",
        "also": [
            "gigawatt",
            "lord_loading_screen",
            "count_copypaste",
            "professor_picklejuice",
        ],
        "primary_problem": "uncover_the_truth",
    },
}

ADVENTURER_VILLAIN_PROBLEMS: dict[str, list[str]] = {
    "gigawatt": ["outsmart_the_trap", "uncover_the_truth", "mend_what_broke"],
    "lord_loading_screen": [
        "mend_what_broke",
        "outsmart_the_trap",
        "earn_their_trust",
    ],
    "doctor_detention": [
        "uncover_the_truth",
        "earn_their_trust",
        "mend_what_broke",
    ],
    "mister_meh": ["give_them_a_voice", "mend_what_broke", "rally_the_allies"],
    "booger_baron": ["earn_their_trust", "mend_what_broke", "broker_a_truce"],
    "llama_of_doom": [
        "expose_the_real_danger",
        "give_them_a_voice",
        "broker_a_truce",
    ],
    "professor_picklejuice": [
        "find_the_fair_path",
        "return_what_was_taken",
        "give_them_a_voice",
    ],
    "count_copypaste": [
        "uncover_the_truth",
        "outsmart_the_trap",
        "mend_what_broke",
    ],
    "the_overlooked": ["give_them_a_voice", "uncover_the_truth", "mend_what_broke"],
    "the_gatekeeper": ["earn_their_trust", "broker_a_truce", "rally_the_allies"],
}


# ---------------------------------------------------------------------------
# Creator-band (ages 12-14) matrix — "Hero Saga" Phase 1.
# A comic-book city, not a fantasy realm. Antagonists are codenamed, morally
# complex figures with a real point of view — a leaker who calls it justice, a
# benefactor who controls heroes "for their own good", a vigilante who tramples
# the innocent chasing the guilty. Tone is action + MYSTERY: the hero
# investigates, out-thinks, de-escalates, and exposes the truth. Resolution is
# ALWAYS non-violent — through courage, reasoning, empathy, teamwork, or
# BOUNDARIES — NEVER through violence, weapons, killing, or fear.
#
# IMPORTANT (therapeutic): empathy is NOT universal redemption. Some villains
# reconsider when genuinely reached; others — the manipulative or unsafe ones —
# are simply STOPPED and held accountable without being harmed or humiliated.
# The ``softens`` beat carries each villain's correct resolution: a changed
# conviction for the reachable ones, a boundary/exposure/accountability for the
# rest. We never imply a child is responsible for fixing someone who won't
# change. No romance.
# ---------------------------------------------------------------------------
CREATOR_VILLAINS: dict[str, dict] = {
    "cipher_zero": {
        "name": "Cipher Zero",
        "action": "leak every private secret in the city, certain that total transparency is the only real justice",
        "softens": "sealed the leaks once the hero proved that privacy is dignity, not a cover for lies",
    },
    "the_optimizer": {
        "name": "the Optimizer",
        "action": "rewrite the city's systems to erase every risk — and every freedom along with it",
        "softens": "powered down the controls after seeing that a life with no choices isn't safe, it's hollow",
    },
    "the_understudy": {
        "name": "the Understudy",
        "action": "sabotage the city's brightest stars after a lifetime of being the overlooked second-best",
        "softens": "stepped out of the shadows the moment the hero made their real gift impossible to ignore",
    },
    "the_magnate": {
        "name": "the Magnate",
        "action": "buy up the old district and quietly erase the people who built it, sure he is 'improving' it",
        "softens": "signed a plan that kept the community inside its own future once the hero showed what value really means",
    },
    "riptide": {
        "name": "Riptide",
        "action": "flood the harbor to take the coast back for the wildlife the city paved over",
        "softens": "agreed to a fair plan that left room for both the city and the sea once someone finally listened",
    },
    "redact": {
        "name": "Redact",
        "action": "erase inconvenient history so the city can never be shamed by its past",
        "softens": "restored the records after learning that facing the past is the only way to not repeat it",
    },
    "gridlock": {
        "name": "Gridlock",
        "action": "freeze the whole city's transit to force everyone to stop ignoring a danger they caused",
        "softens": "let the city move again the moment the real hazard was finally taken seriously and fixed",
    },
    "the_mirror": {
        "name": "the Mirror",
        "action": "expose powerful hypocrites by stealing their reputations — ruining innocent bystanders in the crossfire",
        "softens": "was stopped and its reputation-thefts undone — the innocent cleared and the record set straight — held to account without being humiliated, even though it never fully owned the harm",
    },
    "nightjar": {
        "name": "Nightjar",
        "action": "hunt wrongdoers as a vigilante, trampling the law and the innocent in the chase",
        "softens": "was stopped before crossing the final line and made to answer for the people it hurt — the hero held the boundary instead of becoming what it chased",
    },
    "the_benefactor": {
        "name": "the Benefactor",
        "action": "secretly pull the strings of the city's heroes like puppets, 'for their own good'",
        "softens": "had its hidden strings cut and its control exposed to the whole city, so it could no longer puppet anyone — whether or not it ever admitted it was wrong",
    },
}

CREATOR_PROBLEMS: dict[str, dict] = {
    "expose_the_conspiracy": {
        "name": "Expose the conspiracy",
        "verb": "uncover",
        "summary": "piece together and reveal a hidden scheme",
    },
    "clear_the_framed": {
        "name": "Clear the framed",
        "verb": "prove the innocence of",
        "summary": "prove an innocent person was set up",
    },
    "de_escalate_standoff": {
        "name": "Defuse the standoff",
        "verb": "talk down",
        "summary": "end a dangerous standoff without force",
    },
    "protect_the_source": {
        "name": "Protect the source",
        "verb": "safeguard",
        "summary": "keep a vulnerable witness safe",
    },
    "outwit_the_mastermind": {
        "name": "Outwit the mastermind",
        "verb": "out-think",
        "summary": "beat a clever plan with a cleverer one",
    },
    "broker_the_deal": {
        "name": "Broker the deal",
        "verb": "negotiate",
        "summary": "find terms both sides can live with",
    },
    "reveal_the_cover_up": {
        "name": "Reveal the cover-up",
        "verb": "bring to light",
        "summary": "make a buried truth public",
    },
    "win_back_trust": {
        "name": "Win back trust",
        "verb": "win back",
        "summary": "rebuild trust the hero or city broke",
    },
    "rescue_without_harm": {
        "name": "Rescue without harm",
        "verb": "get everyone out safely",
        "summary": "save people while harming no one — not even the villain",
    },
    "choose_the_harder_right": {
        "name": "Choose the harder right",
        "verb": "make the costly right call for",
        "summary": "do the right thing when it costs the hero something",
    },
}

# Creator powers reuse the 8 base IDs (so the existing picker keeps working)
# with Creator-tier names/verbs, plus 2 Creator-only powers (strategist,
# gadgeteer) tuned to the action+mystery register. A deliberately curated mix
# across lanes — movement, force, perception, influence, empathy, mind, tech —
# so every pick plays differently. Powers win through wits and heart, not force.
CREATOR_POWERS: dict[str, dict] = {
    "super_speed": {
        "name": "Overclock",
        "verb": "move faster than the moment",
        "ideal": "gridlock",
        "also": ["the_optimizer", "riptide", "the_mirror", "nightjar"],
        "primary_problem": "rescue_without_harm",
    },
    "flying": {
        "name": "Skyline",
        "verb": "take the high vantage",
        "ideal": "riptide",
        "also": ["gridlock", "the_magnate", "redact", "the_benefactor"],
        "primary_problem": "reveal_the_cover_up",
    },
    "super_strength": {
        "name": "Kinetic",
        "verb": "move the immovable",
        "ideal": "the_optimizer",
        "also": ["gridlock", "the_magnate", "riptide", "redact"],
        "primary_problem": "rescue_without_harm",
    },
    "super_hearing": {
        "name": "Signal Sense",
        "verb": "catch the whisper under the noise",
        "ideal": "the_mirror",
        "also": ["cipher_zero", "redact", "nightjar", "the_understudy"],
        "primary_problem": "expose_the_conspiracy",
    },
    "super_smile": {
        "name": "Magnetism",
        # NOT mind-control: this power inspires cooperation, steadies courage,
        # and helps people actually hear each other — it never overrides anyone's
        # choices. The T9 prompt must enforce this.
        "verb": "rally people to pull together and hear each other",
        "ideal": "the_understudy",
        "also": ["the_magnate", "the_mirror", "the_benefactor", "riptide"],
        "primary_problem": "win_back_trust",
    },
    "super_hugs": {
        "name": "Anchor",
        "verb": "stand with them when it's hardest",
        "ideal": "nightjar",
        "also": ["the_understudy", "the_mirror", "the_benefactor", "gridlock"],
        "primary_problem": "win_back_trust",
    },
    "super_whisper": {
        "name": "Cool Head",
        "verb": "speak calm into the chaos",
        "ideal": "the_benefactor",
        "also": ["nightjar", "gridlock", "the_optimizer", "cipher_zero"],
        "primary_problem": "de_escalate_standoff",
    },
    "super_sharing": {
        "name": "Equalizer",
        "verb": "make it fair for everyone",
        "ideal": "the_magnate",
        "also": ["redact", "riptide", "the_optimizer", "cipher_zero"],
        "primary_problem": "broker_the_deal",
    },
    # Creator-only powers — frontend exposes these only when band==creator.
    "strategist": {
        "name": "Mastermind",
        "verb": "out-plan the entire scheme",
        "ideal": "the_optimizer",
        "also": ["the_benefactor", "cipher_zero", "gridlock", "the_mirror"],
        "primary_problem": "outwit_the_mastermind",
    },
    "gadgeteer": {
        "name": "Technomancer",
        "verb": "engineer the perfect solve",
        "ideal": "cipher_zero",
        "also": ["redact", "the_benefactor", "gridlock", "the_mirror"],
        "primary_problem": "expose_the_conspiracy",
    },
}

CREATOR_VILLAIN_PROBLEMS: dict[str, list[str]] = {
    "cipher_zero": [
        "expose_the_conspiracy",
        "protect_the_source",
        "reveal_the_cover_up",
    ],
    "the_optimizer": [
        "outwit_the_mastermind",
        "de_escalate_standoff",
        "choose_the_harder_right",
    ],
    "the_understudy": ["win_back_trust", "broker_the_deal", "choose_the_harder_right"],
    "the_magnate": ["broker_the_deal", "reveal_the_cover_up", "win_back_trust"],
    "riptide": ["broker_the_deal", "reveal_the_cover_up", "rescue_without_harm"],
    "redact": [
        "reveal_the_cover_up",
        "expose_the_conspiracy",
        "choose_the_harder_right",
    ],
    "gridlock": ["rescue_without_harm", "de_escalate_standoff", "reveal_the_cover_up"],
    "the_mirror": ["clear_the_framed", "expose_the_conspiracy", "win_back_trust"],
    "nightjar": ["de_escalate_standoff", "choose_the_harder_right", "clear_the_framed"],
    "the_benefactor": [
        "win_back_trust",
        "outwit_the_mastermind",
        "de_escalate_standoff",
    ],
}


# ── Adolescent (15-17) — antihero "double life" matrix (T10) ────────────────
# A distinct, more mature register than Creator: antagonists operate at a
# social / identity / personal scale a teenager actually lives in (secrets,
# reputation, belonging, surveillance), each with a real argument. Powers are
# framed as an "Edge" with a built-in cost. Resolution stays non-violent and
# consequence-driven; nobody is "fixed" by a hug.
ADOLESCENT_VILLAINS: dict[str, dict] = {
    "the_archivist": {
        "name": "the Archivist",
        # Reworked 2026-07-07 (editorial audit finding 3): the_archivist and
        # ledger both used to run on "righteous public exposure of secrets" —
        # near-synonymous villains. This entry now runs on the OPPOSITE axis:
        # institutional data-hoarding and surveillance-for-control. The
        # Archivist never deletes and never exposes; power comes from quiet
        # leverage — the threat of what could surface, not the act of it.
        "action": "quietly catalog every secret, debt, and mistake in the school into a private archive — never deleting anything and never releasing it, holding it in reserve as leverage so people police themselves rather than risk what might surface",
        "softens": "surrendered control of the archive once the hero proved the power was never in what the secrets said, but in who got to decide when they mattered",
    },
    "echo": {
        "name": "Echo",
        "action": "turn every rumor into a verdict, certain the crowd is never wrong",
        "softens": "let the noise die once the hero showed that the loudest story isn't the true one",
    },
    "the_gatekeeper": {
        "name": "the Gatekeeper",
        "action": "decide who belongs and quietly freeze out everyone who doesn't, sure it is protecting the group",
        "softens": "opened the circle once the hero made the real cost of belonging-by-exclusion impossible to ignore",
    },
    "blank": {
        "name": "Blank",
        "action": "erase people's pasts to give them a 'clean slate' — whether they asked for it or not",
        "softens": "restored what it took once the hero proved a past you can't see is one you can't grow from",
    },
    "the_double": {
        "name": "the Double",
        "action": "live a second life pulling strings the hero can't trace, a mirror of the hero's own secret",
        "softens": "was drawn into the open and held to account once the hero refused to use the same methods",
    },
    "the_warden": {
        "name": "the Warden",
        "action": "watch everyone 'for their own safety,' trading every freedom for the feeling of control",
        "softens": "powered down the watch after seeing that a cage is still a cage, however kind",
    },
    "ledger": {
        "name": "Ledger",
        "action": "out every hypocrite by ruining them, sure the collateral damage is just the price of truth",
        "softens": "was stopped and the innocent it burned were cleared — held to account without being humiliated, even though it never fully owned the harm",
    },
    "the_patron": {
        "name": "the Patron",
        "action": "quietly bankroll and steer the people around the hero, 'for their own good'",
        "softens": "had its hidden hand exposed so it could no longer steer anyone, whether or not it ever admitted it was wrong",
    },
}

ADOLESCENT_PROBLEMS: dict[str, dict] = {
    "expose_the_setup": {
        "name": "Expose the setup",
        "verb": "uncover",
        "summary": "piece together and reveal who engineered it",
    },
    "clear_the_framed": {
        "name": "Clear the framed",
        "verb": "prove the innocence of",
        "summary": "prove someone was set up to take the fall",
    },
    "protect_the_cover": {
        "name": "Protect the cover",
        "verb": "keep the secret of",
        "summary": "shield a secret — maybe the hero's own — without lying to the people who matter",
    },
    "defuse_the_pileon": {
        "name": "Defuse the pile-on",
        "verb": "cool down",
        "summary": "stop a crowd before it ruins someone",
    },
    "outthink_the_schemer": {
        "name": "Out-think the schemer",
        "verb": "out-think",
        "summary": "beat a clever plan with a cleverer one",
    },
    "surface_the_truth": {
        "name": "Surface the buried truth",
        "verb": "bring to light",
        "summary": "make a hidden truth public the right way",
    },
    "win_back_trust": {
        "name": "Win back trust",
        "verb": "win back",
        "summary": "rebuild trust the hero broke",
    },
    "choose_the_costly_right": {
        "name": "Choose the costly right",
        "verb": "make the costly right call for",
        "summary": "do the right thing when it costs the hero their cover or their standing",
    },
}

# Edge roster — the 8 base power IDs (so the picker keeps working) reframed as
# capabilities with a COST, plus 2 Adolescent-only Edges (strategist/gadgeteer
# IDs reused for the frontend extras). Powers win through judgment, never force.
ADOLESCENT_POWERS: dict[str, dict] = {
    "super_hearing": {
        "name": "Read the Room",
        "verb": "sense what people are really feeling or hiding — and never be able to switch it off",
        "ideal": "echo",
        "also": ["the_archivist", "the_double", "ledger", "the_warden"],
        "primary_problem": "expose_the_setup",
    },
    "flying": {
        "name": "Ghost",
        "verb": "move unseen and unheard — the better you hide, the more alone you are",
        "ideal": "the_warden",
        "also": ["the_archivist", "blank", "the_double", "the_patron"],
        "primary_problem": "surface_the_truth",
    },
    "super_speed": {
        "name": "Borrowed Time",
        "verb": "buy back a few seconds for a second try — each rewind frays something",
        "ideal": "the_double",
        "also": ["echo", "the_gatekeeper", "the_warden", "ledger"],
        "primary_problem": "clear_the_framed",
    },
    "super_strength": {
        "name": "Nerve",
        "verb": "hold the line when anyone else would fold",
        "ideal": "the_gatekeeper",
        "also": ["the_warden", "the_patron", "blank", "the_double"],
        "primary_problem": "choose_the_costly_right",
    },
    "super_smile": {
        "name": "Pull",
        # NOT mind-control: gets people to actually listen and choose together;
        # never overrides anyone's will. The T10 prompt enforces this.
        "verb": "get people to actually listen and pull together — without ever overriding their choice",
        "ideal": "the_gatekeeper",
        "also": ["echo", "ledger", "the_patron", "the_archivist"],
        "primary_problem": "win_back_trust",
    },
    "super_hugs": {
        "name": "Anchor",
        "verb": "stand with someone when it's hardest",
        "ideal": "ledger",
        "also": ["blank", "the_gatekeeper", "echo", "the_archivist"],
        "primary_problem": "win_back_trust",
    },
    "super_whisper": {
        "name": "Cool Head",
        "verb": "speak calm into the chaos",
        "ideal": "echo",
        "also": ["the_double", "the_warden", "the_gatekeeper", "the_patron"],
        "primary_problem": "defuse_the_pileon",
    },
    "super_sharing": {
        "name": "The Fixer",
        "verb": "even the odds so it's fair for everyone",
        "ideal": "the_patron",
        "also": ["blank", "the_gatekeeper", "ledger", "the_archivist"],
        "primary_problem": "choose_the_costly_right",
    },
    # Adolescent-only Edges — frontend exposes these only when band==adolescent.
    "strategist": {
        "name": "The Tell",
        "verb": "always know when someone is lying — including the people you love",
        "ideal": "the_double",
        "also": ["the_patron", "the_archivist", "echo", "ledger"],
        "primary_problem": "expose_the_setup",
    },
    "gadgeteer": {
        "name": "Bend the Odds",
        "verb": "tilt the small probabilities your way — the luck has to come from somewhere",
        "ideal": "the_patron",
        "also": ["the_gatekeeper", "blank", "the_warden", "ledger"],
        "primary_problem": "outthink_the_schemer",
    },
}

ADOLESCENT_VILLAIN_PROBLEMS: dict[str, list[str]] = {
    "the_archivist": ["expose_the_setup", "protect_the_cover", "surface_the_truth"],
    "echo": ["defuse_the_pileon", "clear_the_framed", "surface_the_truth"],
    "the_gatekeeper": [
        "win_back_trust",
        "choose_the_costly_right",
        "defuse_the_pileon",
    ],
    "blank": ["surface_the_truth", "clear_the_framed", "choose_the_costly_right"],
    "the_double": ["protect_the_cover", "clear_the_framed", "outthink_the_schemer"],
    "the_warden": [
        "surface_the_truth",
        "defuse_the_pileon",
        "choose_the_costly_right",
    ],
    "ledger": ["clear_the_framed", "expose_the_setup", "win_back_trust"],
    "the_patron": ["outthink_the_schemer", "win_back_trust", "surface_the_truth"],
}


_BAND_TABLES: dict[str, tuple[dict, dict, dict, dict]] = {
    "sprout": (VILLAINS, PROBLEMS, POWERS, VILLAIN_PROBLEMS),
    "adolescent": (
        ADOLESCENT_VILLAINS,
        ADOLESCENT_PROBLEMS,
        ADOLESCENT_POWERS,
        ADOLESCENT_VILLAIN_PROBLEMS,
    ),
    "explorer": (
        EXPLORER_VILLAINS,
        EXPLORER_PROBLEMS,
        EXPLORER_POWERS,
        EXPLORER_VILLAIN_PROBLEMS,
    ),
    "adventurer": (
        ADVENTURER_VILLAINS,
        ADVENTURER_PROBLEMS,
        ADVENTURER_POWERS,
        ADVENTURER_VILLAIN_PROBLEMS,
    ),
    "creator": (
        CREATOR_VILLAINS,
        CREATOR_PROBLEMS,
        CREATOR_POWERS,
        CREATOR_VILLAIN_PROBLEMS,
    ),
}


def _band_tables(band: str) -> tuple[dict, dict, dict, dict]:
    """Return (villains, problems, powers, villain_problems) for ``band``.

    Defaults to Sprout if an unknown band is passed — keeps legacy callers
    that don't know about bands working unchanged.
    """
    key = (band or "sprout").strip().lower()
    return _BAND_TABLES.get(key, _BAND_TABLES["sprout"])


def _power_villains(power_id: str, band: str = "sprout") -> list[str]:
    """Ordered list (ideal first) of villains compatible with ``power_id``."""
    _, _, powers_t, _ = _band_tables(band)
    if power_id not in powers_t:
        raise ValueError(
            f"Unknown power '{power_id}' for band '{band}'. "
            f"Valid powers: {sorted(powers_t.keys())}"
        )
    spec = powers_t[power_id]
    return [spec["ideal"]] + list(spec.get("also", []))


def _filter_recents(items: Iterable[str], recents: Iterable[str] | None) -> list[str]:
    """Drop ``recents`` from ``items`` but never return an empty list — if all
    candidates are recent, return the full original list so the story can still
    be generated. Frontend uses this to avoid back-to-back duplicates without
    blocking when the recent-list grows to cover everything.
    """
    items = list(items)
    if not recents:
        return items
    blocked = {r for r in recents if r}
    filtered = [i for i in items if i not in blocked]
    return filtered or items


def pick_pairing(
    power: str,
    seed: int | None = None,
    recent_villains: Iterable[str] | None = None,
    recent_problems: Iterable[str] | None = None,
    *,
    band: str = "sprout",
) -> tuple[str, str]:
    """Return a (villain_id, problem_id) pair that fits the hero's ``power``.

    Selection is biased — but not locked — to the power's ideal villain:
    when the ideal is allowed, it's weighted 2x the others. The chosen
    problem is intersected with the band's villain-problem table so the
    pair is always narratively sensible.

    Args:
        power: A power ID valid for ``band`` (see :data:`POWERS` /
            :data:`EXPLORER_POWERS`).
        seed: Optional deterministic seed (for tests / reproducibility).
        recent_villains: Villain IDs to avoid (last-1 or last-N history).
        recent_problems: Problem IDs to avoid in the same way.
        band: 'sprout' (default, ages 3-5) or 'explorer' (ages 6-8).
            Unknown bands fall back to sprout so legacy callers keep
            working.

    Returns:
        Tuple of (villain_id, problem_id), both valid keys into the
        band's villain/problem tables.
    """
    _villains_t, _problems_t, powers_t, villain_problems_t = _band_tables(band)
    rng = random.Random(seed) if seed is not None else random
    candidates = _power_villains(power, band=band)
    candidates = _filter_recents(candidates, recent_villains)

    # Weighted choice: ideal gets weight 2 (only if still present after the
    # recent-villain filter), every other candidate gets weight 1.
    ideal = powers_t[power]["ideal"]
    weights = [2 if c == ideal else 1 for c in candidates]
    villain_id = rng.choices(candidates, weights=weights, k=1)[0]

    problem_pool = villain_problems_t.get(villain_id, [])
    if not problem_pool:
        # Defensive: fall back to the power's primary problem so we never
        # return an invalid pair, even if a future villain row is missing.
        problem_pool = [powers_t[power]["primary_problem"]]

    problem_pool = _filter_recents(problem_pool, recent_problems)
    problem_id = rng.choice(problem_pool)
    return villain_id, problem_id


def get_band_tables(band: str) -> tuple[dict, dict, dict, dict]:
    """Public accessor for a band's (villains, problems, powers, villain_problems).

    Used by the prompt service to render the band-specific story without
    importing the private helper.
    """
    return _band_tables(band)


def apply_nemesis_override(
    band: str,
    villain_id: str,
    problem_id: str,
    chosen_nemesis: str | None,
) -> tuple[str, str]:
    """C4: replace the server-picked villain with a kid-chosen nemesis.

    The Adventurer (9-12) nemesis picker sends ``hero_nemesis_id``. We must not
    only swap in that villain but also keep the paired ``problem_id`` valid for
    the band: the prompt builder re-rolls BOTH villain and problem whenever
    either is invalid for the band, so an incompatible problem would silently
    throw away the kid's chosen villain. We therefore re-pair the chosen villain
    to a problem it actually fits.

    Args:
        band: The hero's band ('sprout' / 'explorer' / 'adventurer').
        villain_id: The server's surprise-picked villain id.
        problem_id: The server's surprise-picked problem id.
        chosen_nemesis: The client-supplied villain id, or None/"".

    Returns:
        ``(villain_id, problem_id)`` — the chosen nemesis paired with a
        compatible problem when the id is valid for ``band``; otherwise the
        server pick unchanged (unknown/empty/wrong-band ids are ignored).
    """
    chosen = (chosen_nemesis or "").strip()
    if not chosen:
        return villain_id, problem_id
    villains_t, _problems_t, _powers_t, villain_problems_t = _band_tables(band)
    if chosen not in villains_t:
        return villain_id, problem_id
    compatible = villain_problems_t.get(chosen) or []
    if compatible and problem_id not in compatible:
        problem_id = compatible[0]
    return chosen, problem_id


__all__ = [
    "VILLAINS",
    "PROBLEMS",
    "POWERS",
    "VILLAIN_PROBLEMS",
    "EXPLORER_VILLAINS",
    "EXPLORER_PROBLEMS",
    "EXPLORER_POWERS",
    "EXPLORER_VILLAIN_PROBLEMS",
    "ADVENTURER_VILLAINS",
    "ADVENTURER_PROBLEMS",
    "ADVENTURER_POWERS",
    "ADVENTURER_VILLAIN_PROBLEMS",
    "CREATOR_VILLAINS",
    "CREATOR_PROBLEMS",
    "CREATOR_POWERS",
    "CREATOR_VILLAIN_PROBLEMS",
    "pick_pairing",
    "get_band_tables",
    "apply_nemesis_override",
]
