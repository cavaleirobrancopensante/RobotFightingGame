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
		["NARRATOR", "Port Ferrum. Kane Dynamics owns the city and its robot boxing league, where Kane's unpiloted OVERLORD is putting human pilots out of work."],
		["YOU", "My dad was one of those pilots. All he left me was his old robot, rusting under a tarp at the dry dock."],
		["GUS", "{RENT_INTRO}"],
		["ECHO", "[ PAIRING SIGNAL ... HANDLER LINK FOUND ]"],
		["GUS", "Then we start in the gutter. No league will have us yet. Pickup fights at the Rusty Bolt, a few bucks a night."],
		["GUS", "The Open Trials are on Saturday. Thirty-two nobodies, two rounds. Win both and we're in the Scrap League this year."],
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
		["GUS", "Keep winning and the prize money starts coming in. Climb out of the hole, then we talk to the dealer about real parts."],
		["GUS", "And remember: the Open Trials, then the Scrap League, Rust, Iron, Steel, and the Titanium Championship at the top. One rung a year, if we're good."],
		["GUS", "The Rusty Bolt's just down the road. Whoever's at the bar will fight you for a few bucks. Get some practice in before Saturday."],
	]},
	# ---- career moments (shown after the fight that decides them)
	"up_scrap": {"place": "THE SCRAP HEAP RING", "lines": [
		["ANNOUNCER", "...and that's the Open Trials done! Eight nobodies just became somebodies!"],
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
		["GUS", "No money for the parts dealer yet. But out back there's a mountain of dead robots. One dig a week, fresh junk every Sunday. One part per dig."],
		["GUS", "Mostly junk. Once in a while, something good. Whatever you find, I'll bolt it on and you fix it up."],
	]},
	"unlock_storage": {"place": "GUS'S STOREROOM", "lines": [
		["GUS", "Everything ends up in these crates. Parts you take off, parts you buy, and whatever you tear off the other robots and get to keep."],
		["GUS", "Bolt them on from here, fix them up, or sell what you don't need. Even junk is worth a few bucks to the scrap man."],
	]},
	"unlock_style": {"place": "GUS'S BAY", "lines": [
		["GUS", "I watched you out there tonight. You fight like your dad did. All fists, no plan."],
		["YOU", "Is that bad?"],
		["GUS", "It's a style. Every pilot's got one. Tanks soak it up, Strikers hit first, Mechanics keep the thing running, Specialists play dirty tricks."],
		["GUS", "Pick yours in the Bay, under Style. Each one comes with a signature move, and I'll wire it into ECHO for free."],
	]},
	"unlock_shop": {"place": "GUS'S BAY", "lines": [
		["GUS", "Two wins. That's enough prize money to walk into the dealer's without getting laughed out."],
		["GUS", "Parts-R-Us, down by the docks. Kane's leftovers, salvage off the cargo ships, the odd arm that fell off a truck. I don't ask."],
		["GUS", "He restocks every Sunday. Mini parts sip power. Heavy parts hit like a truck but drink the battery dry. He's under Get Parts now."],
	]},
	"unlock_season": {"place": "GUS'S BAY", "lines": [
		["GUS", "Pinned a calendar on the wall. League nights are every other Saturday, cup nights are Wednesdays. Rent's the last Sunday of the month. I circled those in red."],
		["YOU", "You circled all of them."],
		["GUS", "Because I have to pay all of them. Flip it over. The league table, the other pilots, and the bookies' odds. It's all under Season."],
		["GUS", "Half this town bets on fight night. If you want to see what you're betting on, you can go and watch the other fights too."],
	]},
	"unlock_scout": {"place": "GUS'S BAY", "lines": [
		["GUS", "There's a kid at the docks who can sneak into any garage in Port Ferrum with a camera. Sixty bucks, and you see the next robot before you fight it."],
		["GUS", "Thing is, crews talk. If they catch him snooping, they'll change their setup just to spite us. Scout's there when you want it."],
	]},
	"unlock_moves": {"place": "GUS'S BAY", "lines": [
		["GUS", "Your dad used to swear by these. Training chips. Each one teaches the robot a special move. Rocket punches, sweeps, slams."],
		["GUS", "They plug into the head, and a better head holds more of them. The dealer keeps a chip or two, you can have one made to order, and now and then one turns up in the scrapyard."],
		["YOU", "And then I just... do the move?"],
		["GUS", "You punch in the combo on the controller. Practise it. A move you can't pull off is just an expensive paperweight."],
	]},
	"unlock_cups": {"place": "GUS'S BAY", "lines": [
		["GUS", "Phone's been ringing. People want to know who's piloting the dead man's robot."],
		["GUS", "That means the cup promoters will take our entry fee. Cups are fought on Wednesday nights, so Saturdays stay free for the league. Eight pilots, three weeks, straight knockout."],
		["GUS", "Pilots from the bigger leagues show up to those. Good money, good beatings. Have a look under Season, Cups."],
	]},
	"unlock_team": {"place": "GUS'S BAY", "lines": [
		["GUS", "Look at that spares shelf. That's half a robot sitting there doing nothing."],
		["GUS", "Back when I worked for... a big outfit, I built backup robots. When the main one's too beat up to fight, the backup goes in the ring."],
		["GUS", "Build one from your spares under Crew, then hit Send to put it in. Some cups even let you fight as a team."],
	]},
	"unlock_workshop": {"place": "GUS'S BAY", "lines": [
		["GUS", "The dealer sells what the dealer's got. Sometimes you want a part nobody sells."],
		["GUS", "So I cleared the workbench. Tell me the shape, the size, what it should do, and I'll build it from scratch. Costs more than buying, but it's exactly what you want."],
		["GUS", "You'll find it under Get Parts, Made to order. And don't touch the welder without gloves."],
	]},
	"unlock_pilot": {"place": "GUS'S BAY", "lines": [
		["GUS", "People recognise you in the street now, kid. Time you looked like a pilot and not like my nephew."],
		["GUS", "Look under Crew, Pilot. Get a jacket, a haircut, whatever. And the dealer's started carrying controllers. The fancy ones change how the robot handles."],
	]},
	"unlock_paint": {"place": "GUS'S BAY", "lines": [
		["GUS", "We're still running ECHO in your dad's old primer. The crowd cheers for robots they can pick out from the cheap seats."],
		["GUS", "I got some paint off a Kane shipping container. Don't ask. It's in the Bay, under Style & paint."],
	]},
	"unlock_setups": {"place": "GUS'S BAY", "lines": [
		["GUS", "You keep swapping the same parts back and forth before every fight. I'm getting old watching you."],
		["GUS", "So I'll write your builds on the chalkboard. Save one under Setups and I'll bolt the whole thing back on in one go. Parts, chips and paint."],
	]},
	"unlock_randomize": {"place": "GUS'S BAY", "lines": [
		["GUS", "When you're in a hurry, just say Randomize. I'll grab whatever's on the spares shelf and bolt it onto ECHO."],
		["YOU", "Will it work?"],
		["GUS", "It won't be pretty. Might even win."],
	]},
}
