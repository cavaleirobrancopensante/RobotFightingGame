extends RefCounted
## All the story text. Each scene: {"place": where it happens, "lines": [[speaker, text], ...]}
## Scenes: "intro", "pre_N" (before the fight with story rival N, 0-9), "post_N" (after beating them),
## and career moments: "scrap_medal", "scrap_out", "regional_semis", "regional_out", "champ_out".
## Rivals 0-2 fight in the Scrap Heap League, 3-5 in the Regional, 6-8 in the Championship,
## and OVERLORD (9) waits in the Championship final.
## Speakers are defined in SPEAKERS below. Edit freely!
##
## The robots are machines, not minds: ECHO only shows system readouts. The people are the story:
## you, Gus, Kane, and the pilots you fight.

const SPEAKERS := {
	"NARRATOR": {"color": "#b0b0bc"},
	"GUS": {"color": "#f2a65a"},
	"YOU": {"color": "#6fd3ff"},
	"ECHO": {"color": "#7cf05a", "robot": true},
	"KANE": {"color": "#ff5a7a"},
	"ANNOUNCER": {"color": "#f2c230"},
	# rival pilots
	"MARGO": {"color": "#9fd8c8", "face": {"skin": "#d9a07a", "hair": "#e8d36a", "hat": "beanie", "outfit": "#f39c12"}},
	"BRUNO": {"color": "#e0a060", "face": {"skin": "#a8714f", "hair": "#2b2b2b", "hat": "cap", "outfit": "#2c3e50", "beard": true}},
	"SKAR": {"color": "#e056fd", "face": {"skin": "#e8c0a0", "hair": "#e056fd", "hat": "mohawk", "outfit": "#222222", "scar": true}},
	"DR. VOSS": {"color": "#c0c8d8", "face": {"skin": "#f0d6c0", "hair": "#888888", "hat": "bald", "outfit": "#ecf0f1", "glasses": true}},
	"ROSA": {"color": "#ff7b54", "face": {"skin": "#b07850", "hair": "#3b1f14", "hat": "bun", "outfit": "#8e2c1c", "long_hair": true}},
	"NIK & NAT": {"color": "#7fd3ff", "face": {"skin": "#e2b48c", "hair": "#00b7ff", "hat": "", "outfit": "#1f2a44", "goggles": true, "twin": true}},
	"BULL": {"color": "#c9a46b", "face": {"skin": "#c08a64", "hair": "#1a1a1a", "hat": "helmet", "outfit": "#3d2b1f", "beard": true}},
	"IRONSIDE": {"color": "#d0d0d0", "face": {"skin": "#8d5a3b", "hair": "#d8d8d8", "hat": "bald", "outfit": "#4a4a52", "beard": true, "scar": true}},
}

const SCENES := {
	"intro": {"place": "PORT FERRUM, 2047", "lines": [
		["NARRATOR", "Port Ferrum. Kane Dynamics owns the city - and its robot boxing league, where Kane's unpiloted OVERLORD is putting human pilots out of work."],
		["YOU", "My dad was one of those pilots. All he left me was his old robot, rusting under a tarp at the dry dock."],
		["GUS", "Three months behind on rent, kid. Tell me that heap still does something."],
		["ECHO", "[ PAIRING SIGNAL ... HANDLER LINK FOUND ]"],
		["GUS", "Then it starts where everybody starts: the Scrap Heap League, out back of the junkyard. Five fights, pennies a bout."],
		["GUS", "Medal there, you're in the Regional. Make the Regional semis, you're in the Kane Championship - once a year, OVERLORD waiting at the end. First bout's tonight."],
	]},

	"pre_0": {"place": "THE SCRAP HEAP RING", "lines": [
		["MARGO", "Margo, TIN CAN's pilot. Cute antique, rookie. Don't cry when I knock the bolts out of it."],
		["GUS", "Tap a part of her robot to aim at it. I'll shout the rest from the corner. Go!"],
	]},
	"post_0": {"place": "THE SCRAP HEAP RING", "lines": [
		["MARGO", "Ha! You actually pilot that thing. My uncle said you can tell a real pilot by the hands. You've got the hands."],
		["GUS", "Forty people standing on a pile of dead robots, and they LOVED it. Spend the winnings in the garage."],
		["GUS", "(quietly) Two suits in the back row were taking notes. Kane scouts. Already."],
	]},

	"pre_1": {"place": "THE SCRAP HEAP RING", "lines": [
		["BRUNO", "Bruno. I run the docks, and on weekends I run this pile. You're the kid driving the dead man's robot. Your father beat me once. Once."],
		["GUS", "RIVET's all elbows. Take its arms and it can't hit back."],
	]},
	"post_1": {"place": "THE SCRAP HEAP RING", "lines": [
		["BRUNO", "...Paid in full. And kid - Kane's people came asking about you. I told 'em nothing. For your father."],
		["GUS", "Dents cost money. Some weeks we'll be broke - so build a backup robot from your spares. I'll show you in the garage."],
		["GUS", "(muttering) I used to build backups for a living. For... somebody else."],
	]},

	"pre_2": {"place": "THE SCRAP HEAP RING", "lines": [
		["SKAR", "Skar. SCRAPJAW's my baby. Bear trap on the face, my own design. What's that rust bucket's excuse?"],
		["YOU", "ECHO's chest plate says 'handler-operated'. Ever seen a chassis like it?"],
		["SKAR", "...Yeah, actually. Old Kane prototype frame. They scrapped a whole line of 'em years back. Weird you've got one."],
		["ECHO", "[ CHASSIS ID: UNIT 00 - RECORD ERASED ]"],
		["GUS", "Lots of old frames out there. Focus, kid."],
	]},
	"post_2": {"place": "THE SCRAP HEAP RING", "lines": [
		["GUS", "Tip: when you rip a part off and still win, sometimes you get to keep it. Check your Spares."],
		["SKAR", "You got lucky. Rematch someday. And hey - if you ever want that bear trap face, I'll weld it on for free."],
		["YOU", "I'll think about it."],
		["GUS", "You will not think about it."],
	]},

	"pre_3": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["NARRATOR", "The Regional. A real ring, real seats, people in their weekend clothes. Kane Dynamics has entered its own test unit: GEARBOX. No pilot - just a technician with a laptop."],
		["DR. VOSS", "Dr. Voss, Autonomous Combat Division. GEARBOX runs on version 9 of our fight program. You'll find it very... efficient."],
		["KANE", "So this is the scrap-pile sensation. How quaint. A human, holding a robot's hand."],
		["YOU", "Better than holding nobody's."],
		["KANE", "Sentimental. Let's see how sentiment does against eight tons of quality control."],
	]},
	"post_3": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["DR. VOSS", "Impossible. That frame's response time is under four milliseconds. Our handler link was never that fast in testing..."],
		["NARRATOR", "Security doesn't escort you to the exit. They escort you to the glass box above the hall."],
		["KANE", "You're a nuisance with a museum piece. I'll give you twenty thousand for it. Right now. Walk away."],
		["YOU", "No."],
		["KANE", "I didn't buy a city by taking 'no' for an answer. Accidents happen in the pits. To pilots who don't watch their step."],
		["GUS", "(on the way home, pale) She's not a rival, kid. She's a predator. And don't ever let her near that robot again."],
	]},

	"pre_4": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["ROSA", "Rosa. I've piloted HAMMERHEAD for fifteen years. Kane offered me a 'retirement package' last month. Pay me to quit, so a program can take my spot."],
		["YOU", "Did you take it?"],
		["ROSA", "I'm standing here, aren't I? Now come show me why everyone's talking about you."],
		["GUS", "HAMMERHEAD swings like a wrecking ball. Don't stand in front of the big arm. Better yet - take it off."],
	]},
	"post_4": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["ROSA", "Good fight. You read me before I moved. That's piloting. That's what Kane wants to erase."],
		["YOU", "Kane offered me twenty thousand for ECHO. I'm never selling it."],
		["NARRATOR", "Behind you, Gus goes very still. Relieved. And something worse than relieved: afraid."],
		["ECHO", "[ HANDLER LINK: 100% SYNC ]"],
	]},

	"pre_5": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["NARRATOR", "You come back to the bay at midnight. The door is kicked in. The tools are smashed. The power lines are cut clean."],
		["GUS", "Kane's people. They went for the workbench and the control rig - not the robot. They want you unable to pilot."],
		["YOU", "Then I'll pilot with what's left. I rewired the rig on a car battery. It works."],
		["NIK & NAT", "We're Nik and Nat. VOLTAGE has two pilots - one for the arms, one for the legs. Heard what happened to your bay. That's low, even for Kane."],
		["GUS", "VOLTAGE is fast and twitchy. Take out its legs and it's just a very angry lamp."],
	]},
	"post_5": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["NIK & NAT", "Here. Spare power cables, from our garage. Nobody wrecks a pilot's bay. Nobody."],
		["YOU", "Gus. ECHO's memory chip is wiped, but the old logs aren't. Look - test sheets. 'UNIT 00 - HANDLER LINK TRIALS. RESULT: DEFEATED AUTONOMOUS UNITS 14 TIMES OUT OF 14.'"],
		["YOU", "And here: 'PROJECT CANCELLED. REASON: PILOT SALARIES.'"],
		["GUS", "...Get some sleep. Both of us need it."],
	]},

	"pre_6": {"place": "KANE CHAMPIONSHIP ARENA", "lines": [
		["BULL", "Bull. SLEDGE's got two hammers and no brakes, same as me. My boys throw bolts. Don't take it personal."],
		["YOU", "Gus. 'Unit 00.' 'Handler link trials.' You flinch every time. Who wrote those logs?"],
		["GUS", "You don't know what you're asking! You don't know what I did!"],
		["GUS", "...Sorry. Not now. Win this one first. Then ask me again."],
	]},
	"post_6": {"place": "KANE CHAMPIONSHIP ARENA", "lines": [
		["NARRATOR", "Sledge's fans threw bolts again. This time, at their own robot."],
		["BULL", "Heh. My boys picked a side. Listen, rookie - every pilot in this town is watching you now. Rosa, the twins, even Bruno. Don't make us look stupid."],
		["YOU", "The crowd is chanting something."],
		["GUS", "It's ECHO's name, kid. And yours."],
	]},

	"pre_7": {"place": "KANE CHAMPIONSHIP ARENA", "lines": [
		["NARRATOR", "Halfway through the Championship league. Kane watches from her private box, high above the ring."],
		["KANE", "Let me save you the suspense. Unit 00 was our handler-link prototype. With a good pilot, it beat every machine we built."],
		["KANE", "Do you know what a good pilot costs? A cut of every purse, forever. Programs don't ask for a cut. So we buried the project and built OVERLORD."],
		["DR. VOSS", "BRIMSTONE runs version 11. It has studied every one of your fights. Every one."],
		["YOU", "Then it should've studied the pilots you put out of work."],
	]},
	"post_7": {"place": "KANE CHAMPIONSHIP ARENA", "lines": [
		["KANE", "Security. That chassis is Kane Dynamics property. Confiscate it."],
		["NARRATOR", "Guards come through the doors. Gus is already moving."],
		["GUS", "Service tunnel! Get it on the cart, kid, NOW!"],
		["NARRATOR", "You make it through the tunnels under the arena with the robot strapped to a cart and the alarms howling. Bruno's dock truck is waiting at the loading bay."],
		["BRUNO", "Get in. Your father would've done the same for me."],
	]},

	"pre_8": {"place": "KANE CHAMPIONSHIP ARENA", "lines": [
		["NARRATOR", "The night before, you went back to where it all began: the old dry dock, under the crane where your father kept ECHO hidden."],
		["YOU", "I dug around under the crane last night, Gus. Found this. A burned-out handler console. Your name's scratched on the back."],
		["GUS", "...Seven years ago I was an engineer at Kane. I built the handler link. Built this arm out of their parts, too."],
		["GUS", "When they ordered Unit 00 crushed, I smuggled it out and gave it to the best pilot I knew - your father. He kept it hidden here, under the crane."],
		["GUS", "And I'm the one who wrote the report that said pilots were 'too expensive.' Kane used it to fire every one of them. Him first."],
		["YOU", "...And then you rented me the bay next door."],
		["GUS", "I lowered the rent. A lot. It's not enough. It'll never be enough."],
		["IRONSIDE", "Ironside. JUGGERNAUT. I was Gus's pilot, back when he still built for the right side. You two done crying? Good. Let's give 'em a fight."],
	]},
	"post_8": {"place": "KANE CHAMPIONSHIP ARENA", "lines": [
		["IRONSIDE", "Ha. Best beating I've taken in years. Tomorrow I'll be in the front row with every pilot Kane ever fired."],
		["GUS", "Finish the league in the top seven and we're in the playoffs. OVERLORD waits in the final. The whole city will be watching."],
		["YOU", "Gus. Whatever you wrote back then - you also built the thing that's going to prove it wrong."],
		["ECHO", "[ ALL SYSTEMS NOMINAL - HANDLER LINK: 100% ]"],
	]},

	"pre_9": {"place": "THE KANE GRAND HALL - FINAL", "lines": [
		["ANNOUNCER", "LADIES AND GENTLEMEN... THE FINAL OF THE KANE CHAMPIONSHIP!"],
		["ANNOUNCER", "In the red corner: the defending champion, unpiloted, running version 12 of the Kane fight program... OVERLORD!"],
		["ANNOUNCER", "And in the blue corner: the junkyard miracle... ECHO and its pilot!"],
		["NARRATOR", "Dinner jackets and diamonds in the boxes. But the front rows are full of pilots. Margo, Bruno, Skar, Rosa, the twins, Bull, Ironside. They've all brought their old controllers."],
		["KANE", "Tonight the whole city learns that machines don't need people."],
		["YOU", "Tonight they learn what people can do with them."],
	]},
	"post_9": {"place": "THE KANE GRAND HALL - FINAL", "lines": [
		["ANNOUNCER", "OVERLORD IS DOWN! OVERLORD IS DOWN! THE SCRAP-HEAP UNDERDOG IS YOUR NEW CHAMPION!"],
		["KANE", "...Impossible. It had every advantage. Every program. Every simulation."],
		["GUS", "It had no pilot."],
		["NARRATOR", "For a second the arena is silent. Then the front rows stand up - every pilot Kane ever fired - and the whole place explodes."],
		["NARRATOR", "Kane Dynamics' stock fell forty percent by morning. By the end of the month, the league brought back pilot licenses."],
		["ROSA", "My license came in the mail today. First thing I did was frame it."],
		["GUS", "Kid. Your father would have been proud. I'm... I'm proud too. For what that's worth."],
		["ECHO", "[ NEXT OPPONENT? AWAITING HANDLER INPUT ]"],
		["NARRATOR", "THE END... of your first championship. Next year OVERLORD wants its belt back. Till then: cups, and rematches from your garage."],
	]},

	# ---- the first time in the bay
	"first_garage": {"place": "GUS'S BAY", "lines": [
		["GUS", "Welcome to the bay. Don't touch the coffee."],
		["GUS", "No money for the parts dealer yet. But out back there's a mountain of dead robots - one dig after every fight. One part per dig."],
		["GUS", "Mostly junk. Once in a while, something good. Whatever you find, I'll bolt it on and you fix it up."],
		["GUS", "And kid - you owe me a thousand in back rent. Rent and food are another thousand every month. And no repairs on credit - while we're in the hole, we fight with the dents."],
		["GUS", "Keep winning and the prize money starts coming in. Climb out of the hole, then we talk to the dealer about real parts."],
	]},
	# ---- career moments (shown after the fight that decides them)
	"scrap_medal": {"place": "THE SCRAP HEAP RING", "lines": [
		["ANNOUNCER", "...and that's the Scrap Heap League done! Step up for your medal - and mind the rust!"],
		["GUS", "Look at that trophy. Welded out of dead robots. Ugliest thing I ever saw. It's going on the bay wall."],
		["GUS", "And it gets us into the Port Ferrum Regional. A real ring, real seats, real money. It starts week eight."],
		["GUS", "Quiet weeks, there's always a pickup fight down here for a few bucks. And now people know your name, the cups will let you in."],
	]},
	"scrap_out": {"place": "THE SCRAP HEAP RING", "lines": [
		["GUS", "No medal this time. Doesn't matter. Everybody's first season looks like this."],
		["GUS", "The scrap league runs again next year. Till then: pickup fights in the quiet weeks, cups, and we keep building."],
	]},
	"regional_semis": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["ANNOUNCER", "...and that puts them in the SEMIFINALS!"],
		["GUS", "Kid. You know what the semis mean? You're IN. The Kane Championship. Week twenty-two."],
		["YOU", "OVERLORD's championship."],
		["GUS", "Seventeen league fights, then the playoffs. OVERLORD sits out the league and waits in the bracket. Of course it does."],
		["GUS", "But first: finish this Regional. A medal's a medal."],
	]},
	"regional_out": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["GUS", "Not the top four. The Regional comes round again next year - and we'll be better."],
		["GUS", "Till then: cups, pickup fights, and every dollar into that robot."],
	]},
	"champ_out": {"place": "KANE CHAMPIONSHIP ARENA", "lines": [
		["GUS", "We didn't make the playoffs. OVERLORD keeps its belt another year."],
		["YOU", "Next year."],
		["GUS", "Next year. Same week, same arena. We'll be ready."],
	]},
}
