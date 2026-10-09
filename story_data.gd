extends RefCounted
## All the story text. Each scene: {"place": where it happens, "lines": [[speaker, text], ...]}
## Scenes: "intro", "pre_N" (before the fight with story rival N, 0-9), "post_N" (after beating them;
## post_9 is the title, when you win the Titanium Championship), and the year's results:
## "up_<division>", "down", "stay_<division>".
## Rivals 0-2 fight in the Scrap League, 3-5 in the Rust League, 6-8 in the Iron League, and
## OVERLORD (9) is your last fight of a Steel League year. The rest of the story is emergent:
## see talk_lines.gd (gloats, rivalries, revenge, the pilot at the bar).
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
	"MARGO": {"color": "#9fd8c8", "face": {"skin": "#d9a07a", "hair": "#e8d36a", "hat": "beanie", "outfit": "#f39c12", "female": true}},
	"BRUNO": {"color": "#e0a060", "face": {"skin": "#a8714f", "hair": "#2b2b2b", "hat": "cap", "outfit": "#2c3e50", "beard": true}},
	"SKAR": {"color": "#e056fd", "face": {"skin": "#e8c0a0", "hair": "#e056fd", "hat": "mohawk", "outfit": "#222222", "scar": true}},
	"DR. VOSS": {"color": "#c0c8d8", "face": {"skin": "#f0d6c0", "hair": "#888888", "hat": "bald", "outfit": "#ecf0f1", "glasses": true}},
	"ROSA": {"color": "#ff7b54", "face": {"skin": "#b07850", "hair": "#3b1f14", "hat": "bun", "outfit": "#8e2c1c", "long_hair": true, "female": true}},
	"NIK & NAT": {"color": "#7fd3ff", "face": {"skin": "#e2b48c", "hair": "#00b7ff", "hat": "", "outfit": "#1f2a44", "goggles": true, "twin": true}},
	"BULL": {"color": "#c9a46b", "face": {"skin": "#c08a64", "hair": "#1a1a1a", "hat": "helmet", "outfit": "#3d2b1f", "beard": true}},
	"IRONSIDE": {"color": "#d0d0d0", "face": {"skin": "#8d5a3b", "hair": "#d8d8d8", "hat": "bald", "outfit": "#4a4a52", "beard": true, "scar": true}},
}

const SCENES := {
	"intro": {"place": "PORT FERRUM, 2047", "lines": [
		["NARRATOR", "Port Ferrum. Kane Dynamics owns the city and its robot league, and its unpiloted OVERLORD is putting human pilots out of work."],
		["YOU", "My dad was one of those pilots. All he left me was his old robot, rusting under a tarp."],
		["GUS", "{RENT_INTRO}"],
		["ECHO", "[ PAIRING SIGNAL ... HANDLER LINK FOUND ]"],
		["GUS", "It's alive. Old Pike fights anybody at the Rusty Bolt for a hundred bucks. Let's see what you've got."],
	]},

	"pre_0": {"place": "THE SCRAP HEAP RING", "lines": [
		["MARGO", "Margo, TIN CAN's pilot. Cute antique, rookie. Don't cry when I knock the bolts out of it."],
		["GUS", "{PC_KEYS}"],
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
		["BRUNO", "...Paid in full. And kid, Kane's people came asking about you. I told 'em nothing. For your father."],
		["GUS", "Dents cost money. Some weeks we'll be broke and the robot will be a mess. One day we'll want a backup."],
		["GUS", "(muttering) I used to build backups for a living. For... somebody else."],
	]},

	"pre_2": {"place": "THE SCRAP HEAP RING", "lines": [
		["SKAR", "Skar. SCRAPJAW's my baby. Bear trap on the face, my own design. ...Hang on. That chassis is an old Kane prototype frame. They scrapped a whole line of 'em years back. Weird you've got one."],
		["ECHO", "[ CHASSIS ID: UNIT 00 / RECORD ERASED ]"],
		["GUS", "Lots of old frames out there. Focus, kid."],
	]},
	"post_2": {"place": "THE SCRAP HEAP RING", "lines": [
		["SKAR", "You got lucky. Rematch someday. And hey, if you ever want that bear trap face, I'll weld it on for free."],
		["YOU", "I'll think about it."],
		["GUS", "You will not think about it."],
	]},

	"pre_3": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["NARRATOR", "The Rust League. A real ring, real seats, people in their weekend clothes. Kane Dynamics has entered its own test unit, GEARBOX. No pilot, just a technician with a laptop."],
		["DR. VOSS", "Dr. Voss, Autonomous Combat Division. GEARBOX runs on version 9 of our fight program. You'll find it very... efficient."],
		["KANE", "So this is the scrap-pile sensation. How quaint. A human, holding a robot's hand."],
		["YOU", "Better than holding nobody's."],
		["KANE", "Sentimental. Let's see how sentiment does against eight tons of quality control."],
	]},
	"post_3": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["NARRATOR", "Security doesn't escort you to the exit. They escort you to the glass box above the hall."],
		["KANE", "You're a nuisance with a museum piece. I'll give you twenty thousand for it. Right now. Walk away."],
		["YOU", "No."],
		["KANE", "I didn't buy a city by taking 'no' for an answer. Accidents happen in the pits. To pilots who don't watch their step."],
		["GUS", "(on the way home, pale) She's not a rival, kid. She's a predator. And don't ever let her near that robot again."],
	]},

	"pre_4": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["ROSA", "Rosa. I've piloted HAMMERHEAD for fifteen years. Kane offered me a 'retirement package' last month. Pay me to quit, so a program can take my spot."],
		["ROSA", "I said no. Now come show me why everyone's talking about you."],
		["GUS", "HAMMERHEAD swings like a wrecking ball. Don't stand in front of the big arm. Better yet, take it off."],
	]},
	"post_4": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["ROSA", "Good fight. You read me before I moved. That's piloting, and Kane wants it gone."],
		["YOU", "Kane offered me twenty thousand for ECHO. I'm never selling it."],
		["NARRATOR", "Behind you, Gus goes very still. He looks relieved. And under that, afraid."],
	]},

	"pre_5": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["NARRATOR", "You come back to the bay at midnight. The door is kicked in. The tools are smashed. The power lines are cut clean."],
		["GUS", "Kane's people. They went for the workbench and the control rig, not the robot. They want you unable to pilot."],
		["NIK & NAT", "We're Nik and Nat. VOLTAGE has two pilots, one for the arms and one for the legs. Heard what happened to your bay. That's low, even for Kane."],
	]},
	"post_5": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["NIK & NAT", "Here. Spare power cables, from our garage. Nobody wrecks a pilot's bay. Nobody."],
		["YOU", "Gus. ECHO's memory chip is wiped, but the old logs aren't. Look, test sheets. 'UNIT 00, HANDLER LINK TRIALS. RESULT: DEFEATED AUTONOMOUS UNITS 14 TIMES OUT OF 14.'"],
		["YOU", "And here. 'PROJECT CANCELLED. REASON: PILOT SALARIES.'"],
		["GUS", "...Get some sleep. Both of us need it."],
	]},

	"pre_6": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["BULL", "Bull. SLEDGE's got two hammers and no brakes, same as me. My boys throw bolts. Don't take it personal."],
		["YOU", "Gus. 'Unit 00.' 'Handler link trials.' You flinch every time. Who wrote those logs?"],
		["GUS", "You don't know what you're asking! You don't know what I did!"],
		["GUS", "...Sorry. Not now. Win this one first. Then ask me again."],
	]},
	"post_6": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["BULL", "Heh. My boys picked a side. Listen, rookie. Every pilot in this town is watching you now. Rosa, the twins, even Bruno. Don't make us look stupid."],
		["YOU", "The crowd is chanting something."],
		["GUS", "It's ECHO's name, kid. And yours."],
	]},

	"pre_7": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["NARRATOR", "Halfway through the Iron League. Kane watches from her private box, high above the ring."],
		["KANE", "Let me save you the suspense. Unit 00 was our handler-link prototype. With a good pilot, it beat every machine we built."],
		["KANE", "Do you know what a good pilot costs? A cut of every purse, forever. Programs don't ask for a cut. So we buried the project and built OVERLORD."],
		["DR. VOSS", "BRIMSTONE runs version 11. It has studied every one of your fights. Every one."],
		["YOU", "Then it should've studied the pilots you put out of work."],
	]},
	"post_7": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["KANE", "Security. That chassis is Kane Dynamics property. Confiscate it."],
		["GUS", "Service tunnel! Get it on the cart, kid, NOW!"],
		["NARRATOR", "You make it through the tunnels under the arena with the robot strapped to a cart and the alarms howling. Bruno's dock truck is waiting at the loading bay."],
		["BRUNO", "Get in. Your father would've done the same for me."],
	]},

	"pre_8": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["YOU", "I dug around under the crane last night, Gus. Found this. A burned-out handler console. Your name's scratched on the back."],
		["GUS", "...Seven years ago I was an engineer at Kane. I built the handler link. Built this arm out of their parts, too."],
		["GUS", "When they ordered Unit 00 crushed, I smuggled it out and gave it to the best pilot I knew. Your father. He kept it hidden here, under the crane."],
		["GUS", "And I'm the one who wrote the report that said pilots were 'too expensive.' Kane used it to fire every one of them. Him first."],
		["GUS", "Then I rented you the bay next door, cheap. It'll never be enough."],
		["IRONSIDE", "Ironside. JUGGERNAUT. I was Gus's pilot, back when he still built for the right side. You two done crying? Good. Let's give 'em a fight."],
	]},
	"post_8": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["IRONSIDE", "Ha. Best beating I've taken in years. Tomorrow I'll be in the front row with every pilot Kane ever fired."],
		["GUS", "One more league, kid. The Steel League, OVERLORD's table. Finish high enough and we're in the Titanium Championship."],
		["YOU", "Gus. Whatever you wrote back then, you also built the thing that's going to prove it wrong."],
	]},

	"pre_9": {"place": "THE KANE GRAND HALL: FINAL", "lines": [
		["ANNOUNCER", "LADIES AND GENTLEMEN... OVERLORD IS IN THE BUILDING!"],
		["ANNOUNCER", "In the red corner, the defending champion, unpiloted, running version 12 of the Kane fight program... OVERLORD!"],
		["ANNOUNCER", "And in the blue corner, the junkyard miracle... ECHO and its pilot!"],
		["NARRATOR", "Dinner jackets and diamonds in the boxes. But the front rows are full of pilots. Margo, Bruno, Skar, Rosa, the twins, Bull, Ironside. They've all brought their old controllers."],
		["KANE", "Tonight the whole city learns that machines don't need people."],
		["YOU", "Tonight they learn what people can do with them."],
	]},
	"post_9": {"place": "THE KANE GRAND HALL: FINAL", "lines": [
		["ANNOUNCER", "THE TITANIUM CHAMPIONSHIP IS DECIDED! THE SCRAP-HEAP UNDERDOG IS YOUR NEW CHAMPION!"],
		["KANE", "...Impossible. It had every advantage. Every program. Every simulation."],
		["GUS", "It had no pilot."],
		["GUS", "Kid. Your father would have been proud. I'm... I'm proud too. For what that's worth."],
		["NARRATOR", "For a second the arena is silent. Then the front rows stand up, every pilot Kane ever fired, and the whole place explodes."],
		["NARRATOR", "Kane Dynamics' stock fell forty percent by morning. By the end of the month, the league brought back pilot licenses."],
		["NARRATOR", "THE END... of your first championship. Next year OVERLORD wants its belt back, and the whole Steel League wants you."],
	]},

	# ---- the first time in the bay
	"first_garage": {"place": "GUS'S BAY", "lines": [
		["GUS", "Welcome to the bay. Don't touch the coffee."],
		["GUS", "{RENT_GARAGE}"],
	]},
	# ---- career moments (shown after the fight that decides them)
	"up_scrap": {"place": "THE SCRAP HEAP RING", "lines": [
		["ANNOUNCER", "...and that's the Open Trials done! Fourteen nobodies just became somebodies!"],
		["GUS", "We're in the Scrap League, kid. A real table, a fight every other Saturday."],
		["GUS", "Don't celebrate too hard. Down there they eat rookies for breakfast."],
	]},
	"stay_open": {"place": "GUS'S BAY", "lines": [
		["GUS", "We didn't make it through the Trials. A year of pickups and cups, and we try again next year."],
		["GUS", "Every pilot in this town has had a year like this. Fix the robot. Keep swinging."],
	]},
	"up_rust": {"place": "THE SCRAP HEAP RING", "lines": [
		["ANNOUNCER", "...and that's the Scrap League done! Eight of you are moving up, mind the rust on your way out!"],
		["GUS", "The Rust League. Real seats, real money. Next year, kid."],
		["GUS", "And now people know your name, the cups will let you in."],
	]},
	"up_iron": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["ANNOUNCER", "...and they're going UP! Next year, the Iron League!"],
		["GUS", "The Iron League, kid. Kane's people will be watching every fight. Let them."],
	]},
	"up_steel": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["ANNOUNCER", "...and they're going UP! Into the STEEL LEAGUE!"],
		["GUS", "The top table. OVERLORD's table. The whole city watches every other Saturday."],
		["GUS", "Not long ago you were fighting for pennies behind the junkyard. Don't forget that."],
	]},
	"title_in": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["ANNOUNCER", "...and there are your eight for the TITANIUM CHAMPIONSHIP!"],
		["GUS", "We're in, kid. Eight pilots, three nights, one belt. Next year, on the open dates."],
	]},
	"title_out": {"place": "THE KANE GRAND HALL", "lines": [
		["GUS", "Not this time. The belt stays where it is another year."],
		["YOU", "Next year."],
		["GUS", "Next year. Same city. We'll be ready."],
	]},
	"down_open": {"place": "GUS'S BAY", "lines": [
		["GUS", "We're out of the leagues, kid. No table, no Saturday nights."],
		["GUS", "Pickups, cups, and the Open Trials at the start of next year. That's how we get back in."],
	]},
	"down": {"place": "GUS'S BAY", "lines": [
		["GUS", "Bottom of the table. We're going down a league next year."],
		["GUS", "It happens. Ironside went down twice before anyone knew his name. We fix the robot and we climb back."],
	]},
	"stay_scrap": {"place": "THE SCRAP HEAP RING", "lines": [
		["GUS", "Another year in the Scrap League. Not up, not down. Next year we push."],
	]},
	"stay_rust": {"place": "PORT FERRUM SPORTS HALL", "lines": [
		["GUS", "Another year in the Rust League. Till then, cups, pickup fights, and every dollar into that robot."],
	]},
	"stay_iron": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["GUS", "Another year in the Iron League. Kane's people will keep watching. Let them."],
	]},
	"stay_steel": {"place": "TITANIUM CHAMPIONSHIP ARENA", "lines": [
		["GUS", "Not enough for the Championship this year. We stay in the Steel League."],
		["YOU", "Next year."],
		["GUS", "Next year. Same table, same city. We'll be ready."],
	]},
	# ---- Gus explains each part of the garage the first time it opens (one per win)
	"unlock_scrapyard": {"place": "THE SCRAPYARD", "lines": [
		["GUS", "Out back there's a mountain of dead robots. One dig a day. Mostly junk, now and then something good."],
	]},
	"unlock_storage": {"place": "GUS'S STOREROOM", "lines": [
		["GUS", "Every part ends up in these crates: the ones you take off, buy, or tear off other robots. Bolt them on, fix them, or sell them."],
	]},
	"unlock_style": {"place": "GUS'S BAY", "lines": [
		["GUS", "You fight like your dad. All fists, no plan."],
		["YOU", "Is that bad?"],
		["GUS", "It's a style. Pick yours under Style. Each one comes with a signature move."],
	]},
	"unlock_shop": {"place": "GUS'S BAY", "lines": [
		["GUS", "Two wins. Enough to walk into the dealer's without getting laughed out. He restocks every Sunday, under Get Parts."],
	]},
	"brass_invite": {"place": "GUS'S BAY", "lines": [
		["GUS", "Silas at Brassworks & Sons asked about you. He built half the gauges on your dad's robot."],
		["GUS", "He'll open his door for you now. Old Town, past the Rusty Bolt. Mind the steam."],
	]},
	"brass_first": {"place": "BRASSWORKS & SONS", "lines": [
		["SILAS", "So you're the kid. Your father bought his first gauge at this counter. Paid in coins, every one polished."],
		["SILAS", "Everything here is built by hand. Brass, steam and patience. Look all you like."],
	]},
	"hell_invite": {"place": "GUS'S BAY", "lines": [
		["GUS", "Magda from Hellfire Heavy called. She saw you tear parts off and liked it."],
		["GUS", "Her breaker's yard is down on the Docks. Big heavy parts, and she'll sell them to you now."],
	]},
	"hell_first": {"place": "HELLFIRE HEAVY", "lines": [
		["MAGDA", "You're the one ripping arms off in the scrap ring. Good. I buy what's left."],
		["MAGDA", "Everything here hits hard and some of it burns. Don't touch the barrels."],
	]},
	"volta_invite": {"place": "GUS'S BAY", "lines": [
		["GUS", "Volta Motor's people saw your BotMedia. Six hundred followers and they think you're a poster."],
		["GUS", "Their showroom in Midtown will let you in now. Don't buy anything just because it's shiny."],
	]},
	"volta_first": {"place": "VOLTA MOTOR", "lines": [
		["DEX", "Welcome to the future, my friend. Feel that? That's static. That's Volta."],
		["DEX", "Everything on the turntable, built in your grade. Fast, light, and it shocks people. Take a spin."],
	]},
	"nimbus_invite": {"place": "GUS'S BAY", "lines": [
		["GUS", "Captain Wren from Nimbus Aerial called. Four in a row and she wants a look at you."],
		["GUS", "Their hangar's at the Midtown airfield. Light parts, hard to hit. Don't let her talk you into wings."],
	]},
	"nimbus_first": {"place": "NIMBUS AERIAL", "lines": [
		["WREN", "So you're the streak. I test every part in here myself, and I've crashed most of them."],
		["WREN", "Light, quick, hard to hit. If they can't catch you, they can't hurt you. Have a look."],
	]},
	"kane_first": {"place": "KANE DYNAMICS", "lines": [
		["VALE", "Welcome to Kane Dynamics. Kane sells to Steel League pilots and champions."],
		["VALE", "You may look. Please don't touch the glass."],
	]},
	"kane_welcome": {"place": "KANE DYNAMICS", "lines": [
		["VALE", "The Steel League. Kane Dynamics has been expecting you."],
		["VALE", "Everything here is built in your grade. Precision is not cheap. Neither are you, now."],
	]},
	"ship_invite": {"place": "GUS'S BAY", "lines": [
		["GUS", "There's a circus ship in at the Docks. The Menagerie. Their ringmaster saw you on BotMedia."],
		["GUS", "Animal parts, kid. Gorilla arms, tentacles. Go have a look, and count your fingers after."],
	]},
	"ship_first": {"place": "THE MENAGERIE", "lines": [
		["ESME", "Welcome aboard! Mind the gangplank. Everything on this deck bites, rolls or hangs on."],
		["ESME", "Every beast in the show, built in your grade. The crowd loves an animal. Pick one."],
	]},
	"tenryu_invite": {"place": "GUS'S BAY", "lines": [
		["GUS", "Someone from Tenryu Mecha Works saw that special move. They want you at their dojo in Midtown."],
		["GUS", "They came over to beat Kane. Loud, red and white, and they shout their moves. You'll like them."],
	]},
	"tenryu_first": {"place": "TENRYU MECHA WORKS", "lines": [
		["HARU", "You! The one with the big finisher! Welcome to the dojo!"],
		["HARU", "Every Tenryu robot calls its moves and fights with Spirit. Specials cost less, and finishers pay you back. Let's beat Kane together!"],
	]},
	"unlock_season": {"place": "GUS'S BAY", "lines": [
		["GUS", "The calendar. League nights every other Saturday, cups on Wednesdays, rent the last Sunday. The tables and the odds are in here too."],
	]},
	"dad_trophies": {"place": "GUS'S OFFICE", "lines": [
		["GUS", "See those three up there? Your dad's. Scrap, Rust, and the Iron one he swore the judges stole from him."],
		["GUS", "I want your trophies up there next to his."],
		["YOU", "Next to his. Then past them."],
	]},
	"unlock_scout": {"place": "GUS'S BAY", "lines": [
		["GUS", "A kid at the docks will get a camera into any garage for sixty bucks. If they catch him, they change their setup to spite us."],
	]},
	"unlock_moves": {"place": "GUS'S BAY", "lines": [
		["GUS", "Training chips. Each one teaches the robot a special move, and you punch in the combo on the controller. Better heads hold more."],
	]},
	"unlock_cups": {"place": "GUS'S BAY", "lines": [
		["GUS", "The cup promoters will take our entry fee now. Wednesday nights, eight pilots, straight knockout. It's under Season, Cups."],
	]},
	"unlock_team": {"place": "GUS'S BAY", "lines": [
		["GUS", "That spares shelf is half a robot. Build a backup under Crew, and Send puts it in when the main one's too beat up."],
	]},
	"unlock_workshop": {"place": "GUS'S BAY", "lines": [
		["GUS", "Want a part nobody sells? Tell me the shape and what it should do, and I'll build it. Made to order, under Get Parts."],
	]},
	"unlock_pilot": {"place": "GUS'S BAY", "lines": [
		["GUS", "People know your face now. Fix your look on BotMedia, and the dealer sells controllers too, under Gear."],
	]},
	"unlock_paint": {"place": "GUS'S BAY", "lines": [
		["GUS", "The crowd cheers for robots they can spot from the cheap seats. Paint's in the Bay, under Style & paint."],
	]},
	"unlock_setups": {"place": "GUS'S BAY", "lines": [
		["GUS", "Save a build under Setups and I'll bolt the whole thing back on in one go."],
	]},
	"unlock_randomize": {"place": "GUS'S BAY", "lines": [
		["GUS", "In a hurry? Randomize, and I'll bolt on whatever's on the spares shelf. Might even win."],
	]},
}
