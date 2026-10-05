extends RefCounted
## Languages: English (the text in the code), Brazilian Portuguese and Spanish.
## The translations live in i18n_pt.gd / i18n_es.gd as {English: translation}. They're loaded
## into Godot's TranslationServer, so labels and buttons translate themselves, and code calls
## tr() (or I18n.t() in scripts that aren't nodes) on everything else.

const I18nPT = preload("res://i18n_pt.gd")
const I18nES = preload("res://i18n_es.gd")
const LANGS := ["en", "pt", "es"]
const LOCALES := {"en": "en", "pt": "pt_BR", "es": "es"}

static var _loaded := false


static func setup(lang: String) -> void:
	if not _loaded:
		_loaded = true
		for pair in [["pt_BR", I18nPT.T], ["es", I18nES.T]]:
			var tr := Translation.new()
			tr.locale = pair[0]
			var dict: Dictionary = pair[1]
			for k in dict:
				tr.add_message(k, dict[k])
			TranslationServer.add_translation(tr)
	TranslationServer.set_locale(LOCALES.get(lang, "en"))


## Translate a string from code that isn't a Node (no tr() there).
static func t(s: String) -> String:
	return str(TranslationServer.translate(s))
