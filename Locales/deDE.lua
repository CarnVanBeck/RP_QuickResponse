-- Deutsch. Fehlende Keys fallen automatisch auf Englisch (enUS.lua) zurück.
local _, ns = ...

ns.RegisterLocale("deDE", {
    -- Haupt-Button
    TOOLTIP_MAIN_LEFT = "Linksklick: Ring öffnen",
    TOOLTIP_MAIN_RIGHT = "Rechtsklick: Einstellungen",
    TOOLTIP_MAIN_DRAG = "Ziehen: Button verschieben",
    TOOLTIP_MAIN_LOCKED = "Der Button ist fixiert.",

    -- Ring
    TOOLTIP_SLOT_LEFT = "Linksklick: zufälliger Satz",
    TOOLTIP_SLOT_RIGHT = "Rechtsklick: Satz auswählen",
    TOOLTIP_EMPTY = "Noch keine Sätze. Leg welche in den Einstellungen an.",
    TOOLTIP_MORE = "... und %d weitere",

    -- Minimap-Button
    TOOLTIP_MINIMAP_LEFT = "Klick: Einstellungen",
    TOOLTIP_MINIMAP_DRAG = "Ziehen: um die Minimap verschieben",

    -- Chat-Meldungen
    MSG_NO_CATEGORIES = "Du hast noch keine Kategorien. Leg eine in den Einstellungen an.",
    MSG_CATEGORY_EMPTY = "„%s“ hat noch keine Sätze, die gepostet werden können.",
    MSG_POSITION_RESET = "Der Button ist wieder in der Bildschirmmitte.",
    MSG_DISCARDED = "Ein Satz mit Fehlern wurde nicht gespeichert; deine Änderungen daran wurden verworfen.",
    MSG_MAX_CATEGORIES = "Der Ring fasst höchstens %d Kategorien.",
    MSG_BLOCKED = "Das Spiel hat eine Aktion dieses Addons blockiert (%s). Bitte melde das.",
    MSG_HELP = "/rpqr - Einstellungen, /rpqr reset - Button zurück in die Bildschirmmitte",

    -- Einstellungsfenster
    CONFIG_TITLE = "RP - Quick Response",
    CONFIG_CATEGORIES = "Kategorien",
    CONFIG_ENTRIES = "Sätze",
    CONFIG_NAME = "Name",
    CONFIG_ICON = "Symbol",
    CONFIG_SHORT = "Kurz (im Ring angezeigt)",
    CONFIG_FULL = "Voll (wird wie ein Makro ausgeführt)",
    CONFIG_HINT = "Ein Befehl pro Zeile, wie in einem Makro: /s, /e, /y, Emotes wie /winken oder /verbeugen oder jeder andere Befehl. Zeilen ohne Befehl werden gesagt.",
    CONFIG_NO_ENTRY = "Wähle links einen Satz aus oder leg einen neuen an.",
    CONFIG_SAVED = "Gespeichert.",

    BTN_NEW = "Neu",
    BTN_DELETE = "Löschen",
    BTN_UP = "Hoch",
    BTN_DOWN = "Runter",
    BTN_NEW_ENTRY = "Neuer Satz",
    BTN_SAVE = "Speichern",
    BTN_REVERT = "Verwerfen",
    BTN_TEST = "Jetzt posten",
    BTN_RESET_POSITION = "Position zurücksetzen",
    TOOLTIP_ICON_CHOOSE = "Klicken, um ein Symbol zu wählen",
    CHECK_LOCK = "Button fixieren",
    CHECK_MINIMAP = "Minimap-Button",

    NEW_CATEGORY = "Neue Kategorie",
    NEW_ENTRY = "Neuer Satz",
    CONFIRM_DELETE_CATEGORY = "Die Kategorie „%s“ mit allen Sätzen löschen?",

    -- Symbolsuche
    ICON_BROWSER_TITLE = "Symbol wählen",
    ICON_SEARCH = "Name oder Datei-ID",
    ICON_COUNT = "%d Symbole",
    ICON_NONE = "Kein Symbol passt.",
    ICON_UNNAMED = "Symbol ohne Namen",
    ICON_FILE_ID = "Datei-ID: %d",

    -- Prüfung von „Voll“
    ERR_NO_COMMAND = "Zeile %d: Nach dem / fehlt ein Befehl.",
    ERR_LINE_TOO_LONG = "Zeile %d ist länger als %d Zeichen.",
    ERR_EMPTY_LINE = "Zeile %d: Der Befehl hat keinen Text.",
    ERR_NO_TEXT = "„Voll“ braucht mindestens eine Zeile Text.",
    ERR_NO_SHORT = "„Kurz“ darf nicht leer sein.",

    -- Beispiel-Kategorien
    DEFAULT_GREETING = "Begrüßung",
    DEFAULT_GREETING_1_SHORT = "Winken",
    DEFAULT_GREETING_1_FULL = "/e winkt freundlich.",
    DEFAULT_GREETING_2_SHORT = "Seid gegrüßt",
    DEFAULT_GREETING_2_FULL = "/s Seid gegrüßt! Schön, Euch zu sehen.",
    DEFAULT_GREETING_3_SHORT = "Verbeugen",
    DEFAULT_GREETING_3_FULL = "/e verbeugt sich höflich.\n/s Seid willkommen. Möge Euer Weg sicher sein.",

    DEFAULT_FAREWELL = "Abschied",
    DEFAULT_FAREWELL_1_SHORT = "Gute Reise",
    DEFAULT_FAREWELL_1_FULL = "/s Gute Reise, und gebt auf Euch acht.",
    DEFAULT_FAREWELL_2_SHORT = "Nicken und gehen",
    DEFAULT_FAREWELL_2_FULL = "/e nickt und wendet sich zum Gehen.",
    DEFAULT_FAREWELL_3_SHORT = "Bis bald",
    DEFAULT_FAREWELL_3_FULL = "/s Bis zum nächsten Mal!\n/e hebt die Hand zum Abschied.",

    DEFAULT_SURPRISE = "Überraschung",
    DEFAULT_SURPRISE_1_SHORT = "Was?!",
    DEFAULT_SURPRISE_1_FULL = "/s Was um alles in der Welt?!",
    DEFAULT_SURPRISE_2_SHORT = "Erschrocken",
    DEFAULT_SURPRISE_2_FULL = "/e zuckt mit weit aufgerissenen Augen zusammen.",
    DEFAULT_SURPRISE_3_SHORT = "Keuchen",
    DEFAULT_SURPRISE_3_FULL = "/e schnappt nach Luft.\n/s Bei allem, was heilig ist ...",

    DEFAULT_CURSING = "Fluchen",
    DEFAULT_CURSING_1_SHORT = "Verflixt!",
    DEFAULT_CURSING_1_FULL = "/s Verflixt und zugenäht!",
    DEFAULT_CURSING_2_SHORT = "Murmeln",
    DEFAULT_CURSING_2_FULL = "/e murmelt einen Fluch vor sich hin.",
    DEFAULT_CURSING_3_SHORT = "Wut",
    DEFAULT_CURSING_3_FULL = "/e stampft mit dem Fuß auf.\n/s Verfluchtes Pech!",
})
