-- Locales/frFR.lua: French (#36). The first locale, reviewed by a native speaker
-- (the owner). Keyed by the English text (Locales\enUS.lua); a missing entry
-- shows English. Vocabulary, kept the same everywhere:
--   the field (the minefield)  le champ        the board (the window's grid)  le plateau
--   best times (the scores)    meilleurs temps  a personal best                un record
--   a tile  une case   a flag  un drapeau   clear around a number  dégager   a wipe  un wipe
-- French spacing before ! ? : ; is applied at the end (a non-breaking space), so
-- the entries are written with plain spaces.

if GetLocale() ~= "frFR" then return end

local GS = Gnomesweeper
local L = GS.L

GS.LOCALE.decimal = ","
GS.LOCALE.months = { "janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc." }

local T = {
    -- The name of the game's moments
    ["One wrong click. Full wipe."] = "Un mauvais clic, c'est le wipe !",      -- the owner's, as said in Quebec
    ["Beginner"] = "Débutant",
    ["Intermediate"] = "Intermédiaire",
    ["Expert"] = "Expert",
    ["%d%s%d %s %d mines"] = "%d%s%d %s %d mines",

    -- The title bar
    ["Close"] = "Fermer",
    ["Escape closes it too."] = "Échap la ferme aussi.",
    ["Settings"] = "Options",
    ["Opens Options > AddOns > Gnomesweeper: question marks, the first click, left-click clearing, the window size."] =
        "Ouvre Options > AddOns > Gnomesweeper : points d'interrogation, premier clic, dégagement au clic gauche, taille de la fenêtre.",
    ["Gnomeregan music"] = "Musique de Gnomeregan",
    ["On: click to turn it off."] = "Activée : cliquez pour la couper.",
    ["Off: click to play it while the board is open."] = "Coupée : cliquez pour la jouer pendant que le plateau est ouvert.",
    ["It never plays in combat."] = "Jamais en combat.",
    ["Sounds"] = "Sons",
    ["On: click to mute the clicks, the bomb and the cheers."] = "Activés : cliquez pour couper les clics, la bombe et les acclamations.",
    ["Muted: click to hear them again."] = "Coupés : cliquez pour les réentendre.",
    ["The game's own sound settings apply too. The music has its own button."] =
        "Les réglages de son du jeu s'appliquent aussi. La musique a son propre bouton.",
    ["How to play"] = "Comment jouer",
    ["Left-click reveals a tile. Right-click plants a flag on a mine you've found."] =
        "Clic gauche : révèle une case. Clic droit : plante un drapeau sur une mine repérée.",
    ["Middle-click a revealed number (or hold left and right together) to reveal the tiles around it that aren't flagged."] =
        "Clic milieu sur un chiffre révélé (ou gauche et droit ensemble) : révèle les cases autour qui n'ont pas de drapeau.",
    ["It only works when the number of flags around it equals the number."] =
        "Seulement quand le nombre de drapeaux autour égale le chiffre.",
    ["A wrong flag makes it reveal a mine, so check your flags first."] =
        "Un drapeau erroné révèle une mine : vérifiez vos drapeaux d'abord.",
    ["The gnome starts a new game; during a game, it gives this one up."] =
        "La gnome lance une nouvelle partie ; en cours de partie, elle abandonne celle-ci.",
    ["Best times"] = "Meilleurs temps",
    ["Your best at each difficulty, shared by all your characters."] =
        "Votre record à chaque difficulté, partagé par tous vos personnages.",

    -- The difficulty and its list
    ["Difficulty"] = "Difficulté",
    ["Starts a new game."] = "Lance une nouvelle partie.",
    ["Best: %s"] = "Record : %s",
    ["Best: %s by %s"] = "Record : %s par %s",
    ["Won %d of %d"] = "Victoires : %d sur %d",
    ["Not played yet."] = "Jamais jouée.",
    ["Start %s? This game will be lost."] = "Commencer en %s ? Cette partie sera perdue.",
    ["Start"] = "Commencer",
    ["Keep game"] = "Garder la partie",

    -- The HUD and the footer
    ["New game"] = "Nouvelle partie",
    ["Same difficulty."] = "Même difficulté.",
    ["Click the gnome for a new game. During a game, it gives this one up."] =
        "Cliquez sur la gnome pour une nouvelle partie. En cours de partie, elle abandonne celle-ci.",
    ["Got it"] = "Compris",
    ["Choose a tile to begin."] = "Choisissez une case pour commencer.",
    ["Left-click: Reveal     Right-click: Flag"] = "Clic gauche : révéler     Clic droit : drapeau",
    ["Middle-click: Clear around number"] = "Clic milieu : dégager autour du chiffre",

    -- The end of a game
    ["Field cleared!"] = "Champ déminé !",
    ["Time %s"] = "Temps : %s",
    ["Play again"] = "Rejouer",
    ["Boom. Full wipe."] = "Boum. Wipe total.",
    ["Wrong flags are crossed out."] = "Les drapeaux erronés sont barrés.",
    ["Try again"] = "Réessayer",
    ["New personal best!"] = "Nouveau record personnel !",
    ["Best %s"] = "Record : %s",
    ["%s faster than %s"] = "%s de mieux que %s",
    ["New best (-%s)"] = "Nouveau record (-%s)",
    ["New best!"] = "Nouveau record !",
    ["See the field"] = "Voir le champ",

    -- The best times panel
    ["First click: one safe tile (Windows XP's rule)."] = "Premier clic : une seule case sûre (règle de Windows XP).",
    ["First click: always opens an area."] = "Premier clic : ouvre toujours une zone.",
    ["No win yet"] = "Pas encore de victoire",
    ["Not played yet"] = "Jamais jouée",
    ["won %d of %d"] = "victoires : %d sur %d",
    ["You"] = "Vous",
    ["Guild"] = "Guilde",
    ["No time shared yet"] = "Aucun temps partagé",
    ["you: %d of %d"] = "vous : %d sur %d",
    ["%d with a time"] = "%d avec un temps",
    ["Not in a guild."] = "Pas de guilde.",
    ["%s cleared %s in %s, a new guild best!"] = "%s : %s en %s, nouveau record de guilde !",
    ["%s (one safe tile)"] = "%s (une seule case sûre)",
    ["Guild best toasts"] = "Annonces des records de guilde",
    ["When a guildmate with Gnomesweeper sets a new guild best. Never in combat."] =
        "Quand un membre de la guilde qui a Gnomesweeper bat le record de la guilde. Jamais en combat.",

    -- The settings
    ["/gsweep opens the board; the gear in its title bar opens this page."] =
        "/gsweep ouvre le plateau ; l'engrenage de sa barre de titre ouvre cette page.",
    ["Question marks"] = "Points d'interrogation",
    ["Right-click: flag, then ?, then clear."] = "Clic droit : drapeau, puis ?, puis rien.",
    ["First click"] = "Premier clic",
    ["Opens an area"] = "Ouvre une zone",
    ["One safe tile"] = "Une seule case sûre",
    ["One safe tile is Windows XP's rule. Each rule keeps its own best times."] =
        "Une seule case sûre : la règle de Windows XP. Chaque règle a ses propres meilleurs temps.",
    ["Board"] = "Plateau",
    ["Classic"] = "Classique",
    ["Modern"] = "Moderne",
    ["Modern: ice-blue glass tiles. Only the look changes; your game stays as it is."] =
        "Moderne : des cases de verre bleu glacier. Seule l'apparence change ; votre partie reste telle quelle.",
    ["Clear with left-click"] = "Dégager au clic gauche",
    ["Left-click a number whose flags match."] = "Clic gauche sur un chiffre dont les drapeaux correspondent.",
    ["Clicks, flags, the bomb and the cheers. The game's own sound settings apply too."] =
        "Clics, drapeaux, la bombe et les acclamations. Les réglages de son du jeu s'appliquent aussi.",
    ["While the board is open; never in combat. Also the note in the title bar."] =
        "Pendant que le plateau est ouvert ; jamais en combat. Aussi la note dans la barre de titre.",
    ["Hide in combat"] = "Masquer en combat",
    ["A fight puts the window away, paused; it comes back when the fight ends."] =
        "Un combat range la fenêtre, en pause ; elle revient à la fin du combat.",
    ["Fireworks"] = "Feux d'artifice",
    ["Over the board when you beat your best time."] = "Sur le plateau quand vous battez votre record.",
    ["Window size"] = "Taille de la fenêtre",
    ["Shown at %s so it fits the screen."] = "Affichée à %s pour tenir à l'écran.",
    ["Minimap button"] = "Bouton de la minicarte",
    ["Left-click opens or closes the board, right-click opens these settings. Drag it around the minimap."] =
        "Clic gauche : ouvre ou ferme le plateau. Clic droit : ces options. Faites-le glisser autour de la minicarte.",
    ["Reset best times..."] = "Effacer les meilleurs temps...",
    ["Click again to reset"] = "Cliquez encore pour effacer",
    ["Every difficulty's best time and games won, for both first-click rules."] =
        "Les meilleurs temps et les victoires de chaque difficulté, pour les deux règles du premier clic.",

    -- About
    ["About"] = "À propos",
    ["Version %s  ·  for World of Warcraft: Forever  ·  by Spotnick"] =
        "Version %s  ·  pour World of Warcraft: Forever  ·  par Spotnick",
    ["Left-click reveals a tile. Right-click flags it. Clear every tile that isn't a mine."] =
        "Clic gauche : révèle une case. Clic droit : un drapeau. Dégagez toutes les cases qui ne sont pas des mines.",
    ["A number says how many mines touch it."] = "Un chiffre dit combien de mines le touchent.",
    ["Middle-click a number (or hold left and right) to reveal the tiles around it, once its flags match."] =
        "Clic milieu sur un chiffre (ou gauche et droit ensemble) : révèle les cases autour, une fois ses drapeaux en place.",
    ["A wrong flag reveals a mine. The first click is always safe."] =
        "Un drapeau erroné révèle une mine. Le premier clic est toujours sûr.",
    ["The rules are Windows XP Minesweeper's."] = "Les règles sont celles du Démineur de Windows XP.",
    ["Links"] = "Liens",
    ["Report a bug"] = "Signaler un bug",
    ["Click a link, then Ctrl+C to copy it."] = "Cliquez sur un lien, puis Ctrl+C pour le copier.",
    ["Commands"] = "Commandes",

    -- The minimap button and the key binding
    ["Left-click: open or close the board"] = "Clic gauche : ouvrir ou fermer le plateau",
    ["Right-click: settings"] = "Clic droit : options",
    ["Drag: move around the minimap"] = "Glisser : déplacer autour de la minicarte",
    ["Open or close the board"] = "Ouvrir ou fermer le plateau",

    -- The slash commands' help (the commands themselves stay English)
    ["/gsweep - open or close the board (also /gnomesweeper, /minewipe)"] =
        "/gsweep - ouvre ou ferme le plateau (aussi /gnomesweeper, /minewipe)",
    ["/gsweep beginner | intermediate | expert - start a game at that difficulty"] =
        "/gsweep beginner | intermediate | expert - lance une partie à cette difficulté",
    ["/gsweep scores - your best times (also the trophy in the title bar)"] =
        "/gsweep scores - vos meilleurs temps (aussi le trophée dans la barre de titre)",
    ["/gsweep settings - open the settings (Options > AddOns > Gnomesweeper; also the gear)"] =
        "/gsweep settings - ouvre les options (Options > AddOns > Gnomesweeper ; aussi l'engrenage)",
    ["/gsweep music - Gnomeregan's music on or off (also the note in the title bar)"] =
        "/gsweep music - la musique de Gnomeregan, activée ou coupée (aussi la note dans la barre de titre)",
    ["/gsweep combat - hide the window in combat (and bring it back after), on or off"] =
        "/gsweep combat - masquer la fenêtre en combat (et la ramener après), ou non",
    ["/gsweep minimap - show or hide the minimap button"] = "/gsweep minimap - affiche ou masque le bouton de la minicarte",
    ["/gsweep reset - put the window back in the middle of the screen"] =
        "/gsweep reset - remet la fenêtre au milieu de l'écran",
    ["/gsweep scale 0.5 to 1.5 | reset - resize the window (it never grows past the screen)"] =
        "/gsweep scale 0.5 à 1.5 | reset - redimensionne la fenêtre (jamais plus grande que l'écran)",

    -- Chat
    ["Gnomeregan's music on."] = "musique de Gnomeregan activée.",
    ["Gnomeregan's music off."] = "musique de Gnomeregan coupée.",
    ["hide in combat on: a fight puts the window away until it ends."] =
        "masquer en combat activé : un combat range la fenêtre jusqu'à sa fin.",
    ["hide in combat off: the window stays up in combat."] = "masquer en combat désactivé : la fenêtre reste ouverte en combat.",
    ["there is no minimap button: its libraries didn't load (or another addon took the name)."] =
        "pas de bouton de minicarte : ses bibliothèques ne se sont pas chargées (ou un autre addon a pris le nom).",
    ["minimap button shown."] = "bouton de la minicarte affiché.",
    ["minimap button hidden: /gsweep minimap brings it back."] = "bouton de la minicarte masqué : /gsweep minimap le ramène.",
    ["window position reset."] = "position de la fenêtre réinitialisée.",
    ["window scale %s%s. /gsweep scale %s to %s, or reset."] = "taille de la fenêtre %s%s. /gsweep scale %s à %s, ou reset.",
    [" (shown at %s: that is what fits the screen)"] = " (affichée à %s : c'est ce qui tient à l'écran)",
    ["window scale back to 1."] = "taille de la fenêtre remise à 1.",
    ["window scale %s%s."] = "taille de la fenêtre %s%s.",
    ["scale must be a number from %s to %s (or reset)."] = "la taille doit être un nombre de %s à %s (ou reset).",
    ["unknown option '%s'."] = "option inconnue « %s ».",
    ["best times reset."] = "meilleurs temps effacés.",
    ["the settings are in the game's Options > AddOns > Gnomesweeper."] =
        "les options sont dans Options > AddOns > Gnomesweeper.",
}

-- French spacing: a non-breaking space before ! ? : ; and inside « », so a line never
-- breaks before one. (Not inside a format directive: "%s" has no space before it.)
local NBSP = "\194\160"
for k, v in pairs(T) do
    v = v:gsub(" ([!%?:;»])", NBSP .. "%1"):gsub("« ", "«" .. NBSP)
    rawset(L, k, v)
end
