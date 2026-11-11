# Robot Fighting: privacy

**What the game keeps.** Your saves, settings and the playtest log stay on your device (the browser's storage in the web build). There are no accounts, no ads, no analytics and nothing is tracked.

**Fighting a friend, live.** The two games talk through a free public MQTT relay (broker.emqx.io, broker.hivemq.com or test.mosquitto.org, whichever answers first). While the fight is on it carries your robot, your pilot's name and look, your record and your button presses. The relay is public: anyone who knew your five-letter room code could read those messages, so don't put anything private in your names. Nothing else is sent.

**Ghosts and save files.** Ghost codes, result codes and downloaded save files only go where you paste or send them yourself.

**Crash reports.** Nothing is sent automatically. If the game closes unexpectedly, the main menu offers to copy a report (the playtest log and the error log) to your clipboard, and you decide whether to send it.

**Contact.** Salgarellius, through the GitHub repository: https://github.com/cavaleirobrancopensante/RobotFightingGame
