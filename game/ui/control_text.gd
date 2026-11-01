class_name WolfControlText
extends RefCounted
## Presentation-only control copy. Original language tables and story flags stay
## unchanged; keyboard, mouse and HUD instructions describe the actual bindings.
static var replacements: Dictionary={}
static var spaces: RegEx
static var touch_replacements: Dictionary={}
static func adapt(text: String) -> String:
	if text.is_empty():return text
	if spaces==null:
		spaces=RegEx.new();spaces.compile("\\s+")
		var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/texts.json"))
		var ru: Dictionary={
			60:"Проход ведет на север в дикие места.\\n\\nW — вперед. A / D — поворот. S — разворот. Также работают клавиши со стрелками.\\n\\nСледи за картой справа вверху. Enter или Пробел закрывает окно с текстом.",
			61:"Какие-то монстры убили этого мужика. Возьму-ка его нож.\\n\\nВыбирай предмет стрелками рядом с его иконкой, клавишами Q / E или в инвентаре I. Enter или Пробел использует выбранный предмет, если это возможно.",
			62:"На севере виднеется огонь. Нажми M или кнопку «Карта», чтобы увидеть свое положение на большой карте. Неисследованные места — в темноте.",
			72:"Движение занимает один час и тратит Выносливость, особенно ночью. Еда и отдых восстанавливают ее. После отдыха игра сохраняется.\\n\\nНажми «Спать» на нижней панели или R, чтобы отдохнуть.\\n\\nJ или кнопка «Журнал» открывает текущие задачи.",
			231:"Повреждения от оружия и сила врагов показываются точками. Повреждения зависят от места и оружия. Для атаки нажми Enter или Пробел.",
			34:"Останови превращение Жанет Кейн в оборотня: запри три тотема вендиго в серебряной шахте.\\n\\nПередвижение занимает час и расходует Выносливость. Еда и отдых восстанавливают ее. Урон оружия зависит от времени и места.\\n\\nWASD / стрелки — движение и поворот\\nQ / E или стрелки у предмета — выбор предмета\\nEnter / Пробел — действие, закрыть текст\\nM — карта    J — журнал    I — инвентарь    R — спать\\nEsc — меню / назад\\nF2 — оригинальный или широкий вид\\nF5 — сохранить    F9 — загрузить"}
		var en: Dictionary={
			60:"The pass leads north to wilderness.\\n\\nW / Up: move forward. A / D or Left / Right: turn. S / Down: turn around.\\n\\nWatch the map at the top right. Enter or Space closes text windows.",
			61:"Some beast killed this man. I am taking his knife.\\n\\nChoose an item with the arrows beside its icon or open Inventory with I. Enter or Space uses the selected item when possible.",
			62:"There is a fire to the north. Press M or click Map to see your position on the large map. Unexplored areas are dark.",
			72:"Moving takes one hour and costs Stamina, especially at night. Food and rest restore it. Resting saves the game.\\n\\nClick Rest on the bottom bar or press R to rest.\\n\\nPress J or click Journal to see your tasks.",
			231:"Weapon damage and enemy strength are shown as dots. Damage varies by time and place. Press Enter or Space to attack.",
			34:"Stop Janet Cain from becoming a werewolf by enclosing three Wendigo totems inside a silver mine.\\n\\nMoving takes an hour and uses Stamina. Food and rest restore it. Weapon damage varies by time and place.\\n\\nWASD / arrows: move and turn\\nQ / E or item arrows: select an item\\nEnter / Space: act, close text\\nM: map    J: journal    I: inventory    R: rest\\nEsc: menu / back\\nF2: original / wide view\\nF5: save    F9: load"}
		for language: String in ["Русский","English"]:
			var updates: Dictionary=ru if language=="Русский" else en
			for id: int in updates:replacements[spaces.sub(str(catalog[language][id])," ",true).strip_edges()]=str(updates[id]).replace("\\n","\n")
	var normalized: String=spaces.sub(text," ",true).strip_edges()
	for original: String in replacements:
		if normalized.contains(original):return normalized.replace(original,replacements[original])
	return text

static func for_touch(text: String) -> String:
	var adapted: String=adapt(text)
	if adapted.is_empty():return adapted
	if touch_replacements.is_empty():
		var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/texts.json"))
		var ru: Dictionary={
			60:"Проход ведет на север в дикие места.\n\nНажимай стрелки внизу: вверх — идти вперед, влево и вправо — повернуть, вниз — развернуться.\n\nСледи за мини-картой справа вверху. Кнопка «Понятно» закрывает текст.",
			61:"Какие-то монстры убили этого мужика. Возьму-ка его нож.\n\nВыбери предмет стрелками рядом с иконкой или открой инвентарь значком рюкзака сверху. Затем нажми кнопку с ладонью «Действие».",
			62:"На севере виднеется огонь. Коснись значка карты сверху или мини-карты справа, чтобы открыть большую карту. Неисследованные места — в темноте.",
			72:"Движение занимает один час и тратит Выносливость, особенно ночью. Еда и отдых восстанавливают ее.\n\nКнопка с луной «Спать» запускает отдых и сохраняет игру. Значок книги сверху открывает журнал задач.",
			231:"Повреждения от оружия и сила врагов показываются точками. Повреждения зависят от места и оружия. Выбери оружие и нажми «Действие» для атаки.",
			34:"Останови превращение Жанет Кейн в оборотня: запри три тотема вендиго в серебряной шахте.\n\nСтрелки внизу — движение и повороты. Переключай предмет стрелками рядом с его иконкой. Значок рюкзака сверху открывает весь инвентарь. Выбери предмет, затем нажми кнопку с ладонью «Действие».\n\nКарта и журнал — значки карты и книги сверху. Луна «Спать» — отдых с сохранением. В меню с шестерёнкой доступны сохранение, загрузка и меню игры.\n\nКнопка Classic / Remastered меняет вид игры."}
		var en: Dictionary={
			60:"The pass leads north to wilderness.\n\nTap the arrows below: up to move forward, left or right to turn, and down to turn around.\n\nWatch the mini-map at the top right. Tap Continue to close text windows.",
			61:"Some beast killed this man. I am taking his knife.\n\nUse the arrows beside the active item, or tap the backpack at the top to choose from your inventory. Then tap the hand button, Action, to use it.",
			62:"There is a fire to the north. Tap the map icon at the top or the mini-map on the right to open the large map. Unexplored areas are dark.",
			72:"Moving takes one hour and costs Stamina, especially at night. Food and rest restore it.\n\nThe moon button, Rest, lets you rest and saves the game. Tap the book icon at the top to open your journal.",
			231:"Weapon damage and enemy strength are shown as dots. Damage varies by time and place. Select a weapon and tap Action to attack.",
			34:"Stop Janet Cain from becoming a werewolf by enclosing three Wendigo totems inside a silver mine.\n\nUse the arrows below to move and turn. Use the arrows beside the active item or open the backpack at the top. Choose an item, then tap the hand button, Action.\n\nThe map and book icons open the map and journal. The moon button, Rest, saves the game as you rest. The gear menu contains Save, Load and the game menu.\n\nThe Classic / Remastered button switches the view."}
		for language: String in ["Русский","English"]:
			var updates: Dictionary=ru if language=="Русский" else en
			for id: int in updates:
				var keyboard: String=adapt(str(catalog[language][id]))
				touch_replacements[spaces.sub(keyboard," ",true).strip_edges()]=updates[id]
	var normalized: String=spaces.sub(adapted," ",true).strip_edges()
	for original: String in touch_replacements:
		if normalized.contains(original):return normalized.replace(original,touch_replacements[original])
	return adapted
