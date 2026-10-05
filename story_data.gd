class_name Story
extends RefCounted
## All the story text. Each scene: {"place": where it happens, "lines": [[speaker, text], ...]}
## Scenes: "intro", "pre_N" (before championship fight N, 0-9), "post_N" (after winning it).
## Speakers are defined in SPEAKERS below. Edit freely!

const SPEAKERS := {
	"NARRATOR": {"color": "#b0b0bc"},
	"GUS": {"color": "#f2a65a"},
	"YOU": {"color": "#6fd3ff"},
	"ECHO": {"color": "#7cf05a", "robot": true},
	"KANE": {"color": "#ff5a7a"},
	"ANNOUNCER": {"color": "#f2c230"},
}

const SCENES := {
	"intro": {"place": "PORT FERRUM, 2047", "lines": [
		["NARRATOR", "Port Ferrum, 2047. The shipyards are rusting. The factories went quiet years ago."],
		["NARRATOR", "Only one thing still packs a crowd: robot boxing. Two tons of steel, a handler in the corner, and a city screaming for sparks."],
		["NARRATOR", "Kane Dynamics owns the league, the arenas and the champion: OVERLORD. A fighter that doesn't need a handler at all."],
		["GUS", "Three months behind on the bay rent, kid. Please tell me that pile of junk does something."],
		["YOU", "Dug it out from under the old dry-dock crane. Its core was still warm, Gus. Warm, after who knows how long."],
		["ECHO", "...BZZT... SIGNAL... ANSWERED. HANDLER FOUND."],
		["ECHO", "HELLO, PARTNER. I AM ECHO."],
		["GUS", "...A talking scrap-bot. Of course it talks."],
		["GUS", "Fine. The Scrap Championship starts next week. Ten fights between the bottom of the card and OVERLORD. Win, and we eat."],
		["YOU", "And if we lose?"],
		["GUS", "Then you fix what's broken and go again. That's boxing."],
	]},

	"pre_0": {"place": "THE FISH MARKET PIT", "lines": [
		["GUS", "First bout's in the old fish market. TIN CAN. It's a forklift somebody taught to punch."],
		["GUS", "Listen: tap a part of the other robot to aim at it. Head, torso, an arm, a leg. ECHO will go for it."],
		["ECHO", "TARGETING ONLINE. I HIT WHERE YOU POINT, PARTNER."],
		["GUS", "Break a limb and it falls off for good. Same goes for us: anything we lose, we buy again. Anything dented, we repair."],
		["GUS", "Here's the trick: if you AIM at a part and rip it off, it comes off clean. The crew can usually haul it home after a win. Free parts!"],
		["GUS", "And every part matters. Hit the legs and it slows down. Hit the arms and its punches go soft. The scanner marks its weakest part, too."],
		["GUS", "Heads? Small, tough and hard to hit. Go for the head if you like, but don't count on it."],
		["GUS", "Lose the head or the torso and it's lights out. Keep your guard up."],
	]},
	"post_0": {"place": "THE FISH MARKET PIT", "lines": [
		["GUS", "Ha! Did you see that crowd? Forty people and a seagull, and they LOVED it."],
		["ECHO", "I ENJOYED THE SEAGULL."],
		["GUS", "Spend the money in the garage. Arms first. Always arms first."],
		["GUS", "The parts dealer's stock changes after every fight, so if you see something good, grab it before it's gone."],
		["GUS", "And pick a fighting style. Tank soaks hits, Striker hits hard, Mechanic patches itself up, Specialist runs gadgets and chips."],
	]},

	"pre_1": {"place": "DOCK 9 ARENA", "lines": [
		["NARRATOR", "RIVET belongs to the Dock 9 crew. They've never lost a bet, mostly because nobody bets against them."],
		["GUS", "Their bot's all elbows. Aim for its arms and it can't hit back."],
		["GUS", "Want an edge? Pay a scout to peek at their robot from the garage. Careful - sometimes their crew spots the scout and changes their setup."],
		["ECHO", "PARTNER, YOUR HANDS ARE SHAKING."],
		["YOU", "Yeah. Yours aren't."],
		["ECHO", "I DO NOT HAVE HANDS. I HAVE PIPES."],
	]},
	"post_1": {"place": "DOCK 9 ARENA", "lines": [
		["GUS", "The Dock 9 boys actually paid up. That's a first."],
		["ECHO", "THEY CALLED ME 'THE TRASH CAN THAT TALKS BACK'. I HAVE DECIDED TO TAKE IT AS PRAISE."],
	]},

	"pre_2": {"place": "THE CANNERY", "lines": [
		["GUS", "SCRAPJAW. Somebody welded a bear trap to its face and called it a personality."],
		["ECHO", "...I HAVE SEEN THIS CHASSIS DESIGN BEFORE."],
		["YOU", "Where?"],
		["ECHO", "I DO NOT KNOW. THE MEMORY IS... ZEROED."],
	]},
	"post_2": {"place": "THE CANNERY", "lines": [
		["GUS", "Tip: when you rip a part off and still win, sometimes you get to keep it. Check your Spares."],
		["ECHO", "I WOULD LIKE A JAW."],
		["GUS", "You are not getting a jaw."],
	]},

	"pre_3": {"place": "KANE DYNAMICS TEST TRACK", "lines": [
		["NARRATOR", "Fight four is held on Kane Dynamics property. Their test unit, GEARBOX, is a walking armored wall."],
		["KANE", "So this is the scrap-pile sensation. How quaint. A human, holding a robot's hand."],
		["YOU", "Better than holding nobody's."],
		["KANE", "Sentimental. Let's see how sentiment does against eight tons of quality control."],
	]},
	"post_3": {"place": "KANE DYNAMICS TEST TRACK", "lines": [
		["KANE", "Interesting. Your machine reacts to you faster than our sensors react to anything."],
		["GUS", "(quietly) Don't talk to her, kid. And don't let her anywhere near the bot."],
	]},

	"pre_4": {"place": "HARBOR LIGHTS ARENA", "lines": [
		["KANE", "Let's skip the theatre. Ten thousand for the robot. Cash, tonight."],
		["YOU", "Not for sale."],
		["KANE", "Everything is for sale. Some things just take longer."],
		["GUS", "HAMMERHEAD swings like a wrecking ball. Don't stand in front of the big arm. Better yet - take it off."],
	]},
	"post_4": {"place": "HARBOR LIGHTS ARENA", "lines": [
		["ECHO", "PARTNER. WHEN THE WOMAN OFFERED MONEY, MY CORE TEMPERATURE ROSE BY FOUR DEGREES."],
		["YOU", "That's called being scared, buddy."],
		["ECHO", "I DO NOT LIKE IT. PLEASE DO NOT SELL ME."],
		["YOU", "Never."],
	]},

	"pre_5": {"place": "THE SUBSTATION", "lines": [
		["GUS", "Somebody cut the power to our bay last night. And I mean cut. With bolt cutters."],
		["GUS", "Kane's people. I'd bet my good arm on it."],
		["ECHO", "I RAN ON BATTERY AND WATCHED THE DOOR UNTIL MORNING. YOU NEEDED SLEEP. I DID NOT."],
		["GUS", "VOLTAGE is fast and twitchy. Take out its legs and it's just a very angry lamp."],
	]},
	"post_5": {"place": "THE SUBSTATION", "lines": [
		["ECHO", "MEMORY FRAGMENT RECOVERED."],
		["ECHO", "A WHITE ROOM. A VOICE: 'UNIT ZERO FAILED THE AUTONOMY TEST AGAIN. IT KEEPS ASKING FOR A HANDLER.'"],
		["YOU", "Unit Zero?"],
		["GUS", "...Get some sleep. Both of you."],
	]},

	"pre_6": {"place": "STEELWORKS DOME", "lines": [
		["GUS", "SLEDGE. Two hammers, no brakes, and a fan club that throws bolts."],
		["YOU", "Gus. 'Unit Zero.' You flinched when Echo said it."],
		["GUS", "I flinch at a lot of things. Old age. Focus on the fight."],
		["ECHO", "HIS HEART RATE SAYS OTHERWISE."],
	]},
	"post_6": {"place": "STEELWORKS DOME", "lines": [
		["NARRATOR", "Sledge's fans threw bolts again. This time, at their own robot."],
		["ECHO", "THE CROWD IS CHANTING. I CANNOT MAKE OUT THE WORD."],
		["YOU", "It's your name, Echo."],
	]},

	"pre_7": {"place": "KANE TOWER ROOFTOP", "lines": [
		["KANE", "So it's remembering. Then let me save you the suspense."],
		["KANE", "Unit Zero was our first fighter. Brilliant. Fast. And it refused to fight unless a human stood in its corner."],
		["KANE", "A weapon that waits for permission is a flawed weapon. We scrapped it and built OVERLORD."],
		["YOU", "You built a fighter that doesn't need anybody."],
		["KANE", "I built the future. Your robot is a mistake with a heartbeat. BRIMSTONE will correct it."],
	]},
	"post_7": {"place": "KANE TOWER ROOFTOP", "lines": [
		["ECHO", "PARTNER. AM I A MISTAKE?"],
		["YOU", "You're the best mistake anyone ever made."],
		["ECHO", "...SAVING THAT TO PERMANENT MEMORY."],
	]},

	"pre_8": {"place": "THE OLD DRY DOCK", "lines": [
		["NARRATOR", "The semi-final is held where it all began: the old dry dock, under the crane where ECHO was found."],
		["GUS", "Kid. Before you go out there... I owe you the truth."],
		["GUS", "Seven years ago I was an engineer at Kane Dynamics. I built Unit Zero's handler link. Built this arm out of their parts, too."],
		["GUS", "When they ordered it crushed, I smuggled it out and buried it under that crane. Left its pairing signal on, hoping the right person would answer someday."],
		["YOU", "And then you just... rented me the bay next door."],
		["GUS", "I may have lowered the rent. A lot."],
		["ECHO", "GUS. THANK YOU FOR MY SECOND LIFE."],
		["GUS", "Thank me by knocking JUGGERNAUT into the harbor."],
	]},
	"post_8": {"place": "THE OLD DRY DOCK", "lines": [
		["GUS", "That's it. Tomorrow night: OVERLORD. The whole city will be watching."],
		["ECHO", "PARTNER. IF I AM DESTROYED, KEEP MY HEAD. IT IS WHERE I KEEP YOU."],
		["YOU", "Nobody's getting destroyed."],
	]},

	"pre_9": {"place": "KANE ARENA - MAIN EVENT", "lines": [
		["ANNOUNCER", "LADIES AND GENTLEMEN... THE MAIN EVENT OF THE SCRAP CHAMPIONSHIP!"],
		["ANNOUNCER", "In the red corner: undefeated, unbeaten, un-handled... OVERLORD!"],
		["ANNOUNCER", "And in the blue corner: the junkyard miracle... ECHO and its partner!"],
		["KANE", "Tonight the whole world learns that machines don't need people."],
		["ECHO", "TONIGHT THEY SEE WHAT WE CAN DO TOGETHER."],
	]},
	"post_9": {"place": "KANE ARENA - MAIN EVENT", "lines": [
		["ANNOUNCER", "OVERLORD IS DOWN! OVERLORD IS DOWN! THE SCRAP-HEAP UNDERDOG IS YOUR NEW CHAMPION!"],
		["KANE", "...Impossible. It had every advantage."],
		["ECHO", "IT HAD NO PARTNER."],
		["NARRATOR", "Kane Dynamics' stock fell forty percent by morning. Every handler in Port Ferrum went back to work."],
		["GUS", "Kid, listen to that crowd. They're chanting both your names."],
		["ECHO", "UNIT ZERO IS GONE. MY NAME IS ECHO."],
		["ECHO", "AND I WOULD LIKE TO FIGHT AGAIN TOMORROW."],
		["NARRATOR", "THE END... of the first championship. OVERLORD will accept rematches from your garage."],
	]},
}
