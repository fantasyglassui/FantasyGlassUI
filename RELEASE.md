## 11.11.0

**New: a login briefing**
- A few seconds after you log in, one small window says what is waiting: once-a-day crafts that are
  ready, mail on your other characters, raid and dungeon lockouts that reset since you last played,
  rested experience, and the daily and weekly jobs left on your checklist.
- Click a line to open the window it comes from. Nothing waiting, no briefing; a /reload does not
  bring it back. `/fgui briefing` shows it at any time. Switch: "Login briefing: what is waiting".

**New: profession leveling helper**
- A Skill-ups button on the profession window (or `/fgui skillups`): the recipes you know that
  still give skill points, best first. What you can make now comes first, then what needs the fewest
  materials, orange before yellow before green.
- Each line says how many you can make, or what is missing and whether another character holds it.
  Click one to bring it up.

**New: weekly recap**
- Each character's week is noted as you play it: gold made or spent, time played, levels gained,
  raids and dungeons, and its best loot (rare and better). The last eight weeks are kept.
- `/fgui recap` shows last week for all your characters; `/fgui recap this` shows this week so far.
  The login briefing says when a new recap is ready.

**New: Celestial themes, in place of Runic**
- Runic is gone. The third family of themes is now Celestial: 38 night skies. Each window's sky
  deepens toward the top and glows along its foot like a horizon; its stars are sparse and uneven,
  and each window sees a different part of the sky, with a faint Milky Way across it.
- One fine line round each window with a soft glow inside it, and a small star at the top. Large
  windows carry one real constellation (the Big Dipper, Orion, Cassiopeia, Cygnus, Lyra or the
  Southern Cross; a different one per window) and an orbit sweeping across a corner.
- The sky is alive: three layers of bright stars twinkle out of step, motes of starlight drift up
  through each large window, the horizon and the Milky Way breathe, the constellation and the orbit
  glow and fade, the star at the top turns, and every ten seconds or so a shooting star crosses one
  of the large windows that are open. On the minimap the four direction stars twinkle and turn, the
  sun's rays turn, and the round map's outer orbit goes round once in a minute and a half. It is the
  game's own animation, runs only on windows that are showing, and "Reduce motion" holds it all still.
- Action buttons are lit from inside; the divider is a line of light with a star at its middle;
  the class emblems sit on a small night sky inside a ring of star-chart marks.
- The minimap becomes a star chart. Square, as it comes: degree marks along its edges, a star point
  at north, east, south and west, and the sun by day or the moon by night riding along the top by
  the game's clock. Round (the minimap's round switch): a ring of degree marks with the four
  directions, an outer orbit that turns slowly (held still with Reduce motion), and the sun or moon
  on it, noon at the top and midnight at the foot.
- Anyone using a Runic theme is moved to the Celestial theme made from it, with the same accent:
  Granite becomes Polaris, Emberrune becomes Comet, Jadestone becomes Aurora, and so on. Themes by
  place and themes of your own made as Runic move too. The Look tab and the setup list them under
  Celestial.
- The lettering style that was called Runic keeps its face and is now called Engraved.

**New: twelve more accent colors**
- Midnight blue, Ice, Turquoise, Emerald, Chartreuse, Olive, Bronze, Peach, Blush pink, Magenta,
  Lavender and Indigo: 31 in all, in two rows on the Look tab and in the setup, ordered round the
  color wheel. Each accent's name is shown in your language when you point at it.

**New: interface size**
- An Interface size slider beside Text size on the Layout tab (50 to 150%), and Text size now goes
  from 70 to 150%.
- `/fgui uisize 90` and `/fgui textsize 120` set them from chat; asked for during a fight, they wait
  for it to end.

**Polish**
- The option buttons explain themselves: point at one for what it does. The Layout tab's size
  sliders do too.
- Text size and Interface size take effect when you let go of the slider, so the window no longer
  moves under the mouse while you drag.
- If you change the game's own UI scale while Interface size is set, the add-on takes the new scale
  as its base instead of the old one.
- The login briefing waits for What's new, the setup and the login splash to close, waits out a
  fight, and is put away when a fight starts. A raid saved on two difficulties is named once.
- Skill-ups: recipes that need no materials count as ready to make; recipes worth more than one
  point show "+2" and come first among equals; a part of what is missing held by another character
  is counted; the list updates as you craft, buy or learn, and closes with the profession window.
- Weekly recap: loot the game had not described yet is still kept, and a week with no change in gold
  shows it in gray rather than as a gain.
- Login briefing, Weekly recap and Skill-ups are in the Tools menu, on the Tools tab, and have key
  bindings of their own.
- List windows: a line too long to fit is shown in full under the mouse, and the right-hand side no
  longer squeezes out the left.
- The whisper window closes with Escape, like every other window.
- The login briefing also says when your gear needs a repair (below 30%) or your bags have fewer than
  five free slots; click that line to open your bags.
- Skill-ups shows the profession and your skill in its title, such as "Tailoring 125/150".
- Weekly recap: most played character first; a character you only logged in on is left out.
- `/fgui textsize reset` and `/fgui uisize reset` put the size back to how it came.
- Quiet mode asked for during a fight comes on as soon as the fight ends.
- Buttons are named the same way everywhere: "Move panels", "Reset positions", "Role layout",
  "Share layout", "Run setup again", "Report a problem", "Raid tools", "Reset instances", "Show on map".
- Button labels fit their buttons in every language: a label too long is drawn a little smaller, and
  one still too long is cut short with "...", the whole of it in the tooltip. The chat's Copy button
  and the boss note's Edit button are as wide as their label needs.
- `/fgui pull` and `/fgui break` say what they take when given a word instead of a number, and keep to
  1 to 60 (seconds for a pull, minutes for a break).
- Depositing materials with none in your bags says so, instead of "Depositing 0 stacks".
- Mount and the talent-set switch say "Not during a fight" like everything else (the Korean and
  Chinese wording of the old message read as "you are not in combat").
- `/fgui spec` says so when the set does not exist or is the one you are in, instead of nothing.
- A recipe with no materials says so in the shopping list, instead of an empty window.
- Enter makes the profile in the New profile box, and previews a string in the share preview.
- The profile "Use" button and "Turn these on" have tooltips.
- The cursor ring does less work while the mouse is still.
- Fixed: most lettering styles changed nothing when picked on the Look tab until a /reload. The game
  opens a font file only while a loading screen is up, so every bundled face is now loaded with the
  add-on, and any lettering takes effect the moment you click it.
- Fixed: the bag window's Equip best button stood outside the window. The search box now takes the
  room the buttons leave, so the row ends inside the window (the bank's row too).
- The message after switching between theme families names Celestial instead of Runic.

**Polish: the whole add-on, file by file**
- Everything the add-on shows is now translated, in all eight languages: switch descriptions, theme
  names, option texts, the tour, the guide's answers (and the guide understands questions asked in
  your language), the report steps, the shopping and loot windows, the item counts in tooltips,
  boss and run times, times in days, hours and minutes, the info bar's durability and role, and
  the names of the add-on's key bindings in the game's Key Bindings window.
- Every message is a full sentence, and every panel's name is written the same way ("Cast bar",
  "Quest tracker", "Damage meter").
- Commands that take a number say so when it is wrong, and say what they did: removing a bag rule,
  mail rule, goal or talent build, `/fgui talents save` without a name, `/fgui send` with something
  that cannot be sent, `/fgui invword` with two words, `/fgui main` with a word it does not know.
- Forgetting a character in the Characters window takes two right-clicks, so it cannot happen by
  accident; the window can be dragged, and shows who has mail.
- Keybind mode says what a key did before, when you give it to something else.
- A click-cast change made in a fight says when it has been put in place; a summon held back by a
  fight says it will be taken when the fight ends; quiet mode says when it is off.
- The damage meter says it fills during a fight instead of being an empty panel, and
  `/fgui meter reset` works when it is a window of its own too.
- Your characters beside the mail window have tooltips, keep their class colors under the mouse, and
  explain the * on a character from another realm.
- The layout gallery's picture key says "accent color", as the pictures are drawn.
- Reputations at the top of their standing no longer show "0 / 0"; a web address in chat followed by
  a full stop no longer takes the full stop into the link.
- The friends list on the info bar says how many more are online when the list is cut short.
- Fixed: a new profile could share some of its settings (window places, info bar pieces, panel
  rules, bar settings) with every other profile made in the same session.
- Translations corrected: the tab names in every language now match the real tabs, the Chinese
  word for a gear set, and the German "your rules". The accent colors, the theme names, the tour,
  the problem report's steps, the profile messages (made, deleted, imported, why not), the click-cast
  buttons' names, the class color note on the Look tab and the "Done" mark in the quest log follow
  your language too.
- Messages that were English whatever your language now follow it: the login line, the self-test,
  the panel names of party and boss frames in move mode, the quest tracker's "Ready to turn in", the
  raid preview's players, the loot roll sample, and the Language button's tooltip.
- Action bars: the right-click menu is translated, the game's bars are named "Bar 1" to "Bar 8",
  "Pet bar" and "Stance bar", and when Edit Mode cannot be used the reason is a whole sentence.
- Custom alerts say plainly why one cannot be made (no such alert, needs a number, needs a buff or
  an ability, twenty is the most).
- Selling junk and repairing show the game's coin icons in their messages.
- Bag window: its title, the Grid and Categories button, the section headings, the free-slot count and
  the empty-slot tips follow your language; the bank's Tabs, Deposit and Blizzard bank buttons and
  Sell junk have tooltips; the bank tabs' tooltips are translated.
- The whisper window's reply box looks like the rest of the add-on and says what to type; friends'
  class colors in the friends list are exact.
- The notepad: clicking anywhere on the page puts the cursor in it. When the calculator cannot work
  something out, it says why in your language.
- Chat bubbles do far less work: their lettering is set only when its size changes.
- Buttons with a label color of their own (talent set buttons, the notepad's pages, your characters
  beside the mail window) keep it when the mouse leaves them.
- `/fgui language` lists Chinese among the choices; the quest log and tracker say in plain words when
  this game client cannot hand them its quests.
- The bags and characters windows' "nothing recorded yet" and "nothing matches" notes are translated.
- Fixed: a Health text option in the raid frame designer could show "table: 0x..." instead of its
  choice.

**Polish: a second look at every file**
- Fixed: chat messages from the add-on could start with its name twice ("Fantasy Glass UI: Fantasy
  Glass UI: ...").
- Fixed: the names in the game's Key Bindings window stayed English although their translations were
  there. They now follow your language, and change with it.
- Fixed: choosing "None" for chat timestamps in the game's settings was undone at every login. The
  add-on now switches timestamps on once, and leaves your choice alone after that.
- Fixed: on a game that does not report how much breath is left, the breath bar stood still. It now
  counts down by itself, and holds while the timer is paused.
- Fixed: the loss-of-control sample shown in move mode stayed on screen afterwards.
- Talent builds are learned one point at a time, lowest tier first, so a build is never refused for
  asking too much at once; a fight puts the rest on hold, and it says so.
- The storage window scrolls when a character has more than fits on the screen; its title and tabs
  are translated.
- The role display's alerts (execute range, aggro, low mana, low durability, who your target is
  attacking) are translated, and follow the color-blind setting.
- The color-blind setting now reaches every "good" and "bad" color: messages in the options, the
  raid check, the quest log, ready and missing marks, the cast bar's "Interrupted", the aggro and
  loss-of-control alerts, the swing timer's "out of range", the enchant check and the upgrade line
  on tooltips.
- Debuffs on you are framed in the game's color for what can remove them (magic, curse, poison,
  disease), red for the rest.
- A change of theme now reaches the options window's heading, the bag window's title, the swing
  timer bars and the buff alerts at once, without a /reload.
- The dividers on your class resource bar move with the player frame when you resize it.
- Switches and sliders keep their label inside the row in every language (cut short with "..." and
  shown whole under the mouse); search boxes and their hints fit their window.
- The quest log is translated throughout (levels, rewards, experience, choose one, track) and drawn
  in your theme's colors.
- "Objective complete", the raid tools' "To party" button, the options row of the action bar menu,
  the arena enemy names, the undo messages in move mode and the item and spell numbers on tooltips
  follow your language.
- On the Celestial minimap, the sun and moon ride inside the top edge instead of on it.
- Hiding the talking head also stops its voice; quest sounds play at your sound-effects volume.
- The keybind panel names buttons the way the game's Key Bindings window does.
- Raid and party frames say "Offline" and "Dead" in your language (the game's own words).
- The list of changes to a profile names each setting the way the options do ("Panel positions:
  Cast bar", "Fade when not in use: Bar 2"), with on and off in words, instead of its stored name.
- Nameplates: after a change in the nameplate designer, the target highlight kept working only on
  new plates; it now follows your target on every plate. More or fewer debuffs allowed show at once.
- Click-cast bindings saved without a modifier are no longer skipped.
- The boss note editor looks like the add-on's other text boxes, and a click anywhere in it puts
  the cursor in the note.
- The tour's cards stay on the screen beside a panel near its edge.
- "Where to level" says blue instead of green for your level when the color-blind setting is on.
- The group cooldowns panel keeps long names inside it, and uses the color-blind setting for
  cooldowns still running.
- The demo banner and the characters window's note fit in every language.
- The guide finds the answer about languages when asked in Italian, Portuguese, Russian, Korean or
  Chinese too.
- Chat bubbles have a Celestial look of their own: a small piece of night sky with a few stars, a
  fine line with a soft glow, and the small star at the top. (They were dressed as Fantasy bubbles.)
- The weapon imbue reminder appears and goes without fading when "Reduce motion" is on, and uses
  the color-blind setting.
- The role display shows a sample while you move panels, so it can be seen and placed.
- A layout kept for a screen whose size the game would not give is named "this screen" in the
  messages, instead of nothing.
- Fixed: opening the Combat tab emptied the buff alert boxes, so pressing Apply afterwards cleared
  your buff alerts. The boxes now show the list you saved.
- Fixed: in the custom alert editor, the box for the number or name always said "value"; it now says
  "a number" or "a name", whichever the alert needs.
- The Tools tab's sliders (master volume and the rest) show what is set each time the tab opens,
  so a volume changed in the game's own settings is shown right; showing it never changes it.
- The role names in the setup are translated, and so is "by" in the setup's and the options'
  headings, and the "custom" mark on class colors.
- After a preset on the Features tab, switches whose parent is now off are dimmed at once.
- A section name cut short in the list down the left of the options shows whole under the mouse.
- Clearing a place's theme under Theme by place puts the right theme back at once when you are
  standing there.
- The Reset positions button goes back to its name as soon as it has done its job.
- The theme card beside the Look tab's buttons stays on the screen.
- More good and bad colors in the options follow the color-blind setting (profile messages, "in use",
  layout import, the class suggestions on the Tools tab).
- The login briefing says "Only 1 bag slot free" rather than "1 bag slots".
- Fixed: switching "Mana & resources as numbers" changed the text on your frames only at the next
  change of mana; it now changes at once, as the health option always did.
- Debuffs on the player, target and focus frames and on the add-on's raid frames are framed in the
  game's color for what can remove them (magic, curse, poison, disease), red for the rest.
- The tank and healer marks on raid frames use the first letter of the game's own word for the
  role, in your language.
- Raid frames: a new ready check straight after another keeps its marks (the old one's timer no
  longer clears them); the sample players while previewing are laid out as the raid frame designer
  says (across or down, so many to a column, with its spacing).
- A new width from the frame designer moves the combo point dividers with it.
- With "Reduce motion" on, your frame's idle dimming and the login splash change at once, without
  fading.
- The ready-check report and finished goals follow the color-blind setting.
- The options row in the game menu list takes the current accent color after a theme change.

**Performance**
Every job the add-on repeats while you play was measured, with windows open and closed, in and out
of combat. With every window closed, the add-on now makes about a third of the garbage it made
before while you stand about, and well under half of it in a fight, so the game has less to
clean up after it.
- Chat bubbles are only looked for in the few seconds after someone speaks, rather than ten times a
  second all the time.
- The class resource (combo points, holy power, chi and the rest) now changes the moment the game
  says it has, and no longer rebuilds its settings ten times a second.
- The buff row is redrawn once a second only while a weapon enchant is ticking down. Everything
  else on it is redrawn when your buffs change.
- An open right-click menu is cheaper: its submenus are found by a signature worked out once per
  menu, and the screen is searched for them ten times a second rather than twenty.
- An open quest dialog is relit without making new lists ten times a second.
- Fixed: after a profile switch, the class resource kept the old profile's width and spacing until
  you changed one of them.
