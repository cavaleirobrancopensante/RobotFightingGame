extends RefCounted
## Emergent talk: lines the world's pilots (and Gus) say when something happens between you and
## them, with %s filled in (their name, your name, a league). Edit freely. Keep them short, and
## no dashes: periods and commas only (a dash only when someone gets cut off).
##
## Each list is picked from at random (seeded, so the same moment says the same thing).

## Your very first loss: whoever beat you rubs it in. (%s = your pilot's name)
const GLOAT := [
	"Ha! %s, right? Welcome to the big bad world, rookie. Bring a mop next time.",
	"That's it? I've had harder fights with a vending machine. Better luck next time, %s.",
	"Tell your mechanic the old man needs new glasses. That robot's held together with hope, %s.",
]

## They beat you a second time: now it's personal. (%s = your name)
const RIVAL_BORN := [
	"Twice, %s. I'm starting to think this is a habit. See you around.",
	"Two for two. Maybe find another hobby, %s? Knitting's nice.",
	"You again? And the same result again. I could get used to this, %s.",
]
## Gus, when a rivalry starts. (%s = their name)
const GUS_RIVAL := [
	"That's twice %s has put you on the floor. We've got ourselves a rival, kid.",
	"%s again. Every pilot gets one. That one's yours. Write the name down.",
]

## You finally beat your rival. (%s = your name)
const REVENGE := [
	"...Fine. You got me, %s. Don't get used to it.",
	"Lucky night. Enjoy it, %s. It won't happen twice.",
	"Huh. You learned something. Next time I won't be so nice, %s.",
]
const GUS_REVENGE := [
	"Now THAT tastes better than my coffee. %s won't sleep tonight.",
	"Payback from %s. Frame that one, kid.",
]

## Your rival beats you again. (%s = your name)
const RIVAL_AGAIN := [
	"Same old story, %s. Call me when you've got a real robot.",
	"I'm keeping a tally, %s. It's getting long.",
]

## You beat someone from a higher league in a pickup fight. (%s = their name, %s = their league)
const GIANT_KILL := [
	"You just beat %s from the %s. People are going to talk about that one, kid.",
	"%s! From the %s! Half the bar saw that. Drinks are on you.",
]

## Before a fight against your rival. (%s = your name)
const TAUNT := [
	"Saw your name on the card, %s. I'll make it quick.",
	"Here we go again, %s. Bring a bigger wrench.",
	"Tonight's the night you finally beat me, %s? No. It isn't.",
]

## They've started to hate you (it doesn't matter if you even remember them). (%s = your name)
const THEY_HATE := [
	"Enjoy it, %s. I'm going to remember this one. Every bolt of it.",
	"That fight cost me everything. I won't forget your name, %s.",
	"Laugh it up, %s. I'll be back for you. Count on it.",
]
## Someone who hates you, after you beat them again. (%s = your name)
const NEXT_TIME := [
	"I'll get you next time, %s.",
	"This isn't over, %s. Not even close.",
	"Again? Fine. Next time it's my turn, %s.",
]
## Hate mail: someone who hates you calls out of nowhere. (%s = your name, %d = a week)
const HATE_MAIL := [
	"Week %d, %s. You think I forgot? I didn't.",
	"Just checking you're still around, %s. Week %d. I've been working on my robot.",
	"%s. I watch every fight of yours now. Week %d still keeps me up at night.",
]
## Gus, when someone you've never thought about turns out to hate you. (%s = their name)
const GUS_THEY_HATE := [
	"%s? Huh. You don't even remember them, do you? They remember you.",
	"Funny thing about this sport, kid. You beat somebody once and forget. They don't. Watch out for %s.",
]

## Streaks. Gus talks.
const GUS_LOSING := [
	"Three in a row on the canvas. Happens to everybody. Fix the robot, sleep, we go again.",
	"Rough patch, kid. Look at the parts, not the scoreboard. The scoreboard follows.",
]
const GUS_WINNING := [
	"Five straight wins. Don't let it go to your head. Let it go to the robot.",
	"Five in a row! Folks at the Rusty Bolt are starting to say your name.",
]

## The pilot at the bar in The Rusty Bolt, when you walk in.
## Higher league than you. (%s = your name)
const PUB_STAR := [
	"You're %s? The kid from the bottom. Buy me a drink and maybe I'll go easy on you in a pickup.",
	"Slumming it tonight. If you want a real fight, %s, I'm right here.",
	"Don't stare, %s. Yes, it's me. Fancy getting beaten by a professional?",
]
## Same league. (%s = your name)
const PUB_PEER := [
	"Saw your last fight, %s. Not bad. Fancy a pickup at the scrapyard tonight?",
	"Hey, %s. I could use the money. Pickup fight, you and me?",
	"%s! Sit down. Loser of the next pickup buys the round.",
]
## Still at the bar from last night, in the morning. (%s = your name)
const PUB_HUNGOVER := [
	"Ugh. %s? Not so loud. What time is it?",
	"Don't look at me like that, %s. I live here now.",
	"Mmph. A fight? Sure. Ask me tonight, %s. Or tomorrow.",
]
## Lower league. (%s = your name)
const PUB_ROOKIE := [
	"Wait, you're %s? I watch all your fights! Would you fight me? Just once?",
	"Hey %s. I'm going to be where you are one day. Want to see how close I am?",
]
## Your rival is at the bar. (%s = your name)
const PUB_RIVAL := [
	"Well, look who it is. Want to lose again tonight, %s?",
	"%s. Sit somewhere else. Or meet me at the scrapyard and make it quick.",
]

## A friend is at the bar. (%s = your name)
const PUB_FRIEND := [
	"%s! Pull up a stool. Want to team up tonight? I know two clowns who need a lesson.",
	"There's my favourite pilot. Tag team tonight, %s? You take the big one.",
	"Good to see you, %s. First round's on me. Second round we fight together.",
]

# ---------------------------------------------------------------- relationships (1.58)

## Gus, when someone turns into your nemesis. (%s = their name)
const GUS_NEMESIS := [
	"%s again. That's not a rival any more, kid. That's your nemesis. Beat them and it's settled.",
	"You and %s are past rivals. Nemesis. Only a win against them settles it.",
]
## Gus, when you beat your nemesis. (%s = their name)
const GUS_NEMESIS_DOWN := [
	"You beat %s. Score settled. They're just a rival now. Sleep well tonight, kid.",
	"That's %s dealt with. Nemesis no more. I'm buying the beers.",
]
## Crossing into friendship: a message from them. (%s = your name)
const FRIEND_BORN := [
	"Hey %s. You're alright. Need a hand some night, you know where I drink.",
	"%s, I've got your back. Tag team any time, just ask at the Rusty Bolt.",
	"Friends don't come easy in this city, %s. Glad I found one.",
]
## A friend beat you. (%s = your name)
const FRIEND_FIGHT_WON := [
	"No hard feelings, %s. Drinks are on me tonight.",
	"Good fight, %s. You made me work for it.",
]
## You beat a friend. (%s = your name)
const FRIEND_FIGHT_LOST := [
	"You earned that one, %s. Next time I won't go easy.",
	"Fair and square, %s. Still friends. Barely.",
]
## Your tag partner, after a win together. (%s = your name)
const TAG_WON := [
	"That's how it's done, %s! Same time next week?",
	"We make a good team, %s. Remind me never to fight you.",
	"Ha! Did you see their faces, %s? Beers on me.",
]
## Your tag partner, after a loss together. (%s = your name)
const TAG_LOST := [
	"We'll get them next time, %s. Thanks for having my back.",
	"Rough night, %s. Still glad you were in my corner.",
]


static func pick(list: Array, seed_text: String) -> String:
	return str(list[absi(hash(seed_text)) % list.size()])
