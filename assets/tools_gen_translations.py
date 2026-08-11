"""Gera os arquivos de traducao a partir de UMA tabela.

POR QUE UM GERADOR: sao 23 idiomas x 5 arquivos. Editar 115 JSON a mao garante
que um deles fique com uma chave a menos, e chave faltando nao da erro -- o jogo
cai para o ingles em silencio, entao o defeito so aparece para quem joga naquele
idioma. Aqui a lista de chaves e uma so; se um idioma nao tiver uma string, a
ausencia e deliberada e visivel na tabela.

ESCOPO, e ele e deliberado: sao traduzidos os ROTULOS CURTOS -- nome do item,
titulo do container, menu de contexto, rotulos de acao e os rotulos das opcoes de
sandbox. As TOOLTIPS longas ficam so em ingles.

A razao nao e preguica, e sim como o fallback funciona: chave AUSENTE cai para o
ingles, chave ERRADA nao cai para nada -- fica errada para sempre. Rotulo curto e
verificavel; um paragrafo tecnico em tailandes ou africaner, escrito por quem nao
fala a lingua, e risco puro por pouco ganho. As tooltips entram quando houver
revisao de quem fala o idioma.

CONFIANCA: alta em ES, FR, IT, DE, NL, PT, PTBR, CA. Media em PL, RU, UA, CS, HU,
NO, TR. Baixa em CN, CH, JP, KR, TH, VI, AF -- estes merecem revisao antes de
publicar. Ver docs/traducoes.md.

Uso:
    python tools_gen_translations.py
"""
import io
import json
import os
import sys

# O console do Windows e cp1252 e engasga ao imprimir nomes como "Portugues
# Brasileiro" ou "Русский". Sem isto o gerador morre no meio, deixando parte dos
# idiomas escrita e parte nao -- que e pior que nao rodar.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

OUT = "../Contents/mods/MNWheelbarrow/42/media/lua/shared/Translate"

# Ordem das strings em cada idioma. Mudar a ordem aqui exige mudar a tabela.
FIELDS = (
    "wheelbarrow",      # nome do item, titulo do container e nome da pagina
    "put_down",         # menu de contexto
    "load_into",       # menu de contexto: carregar varios de uma vez
    "picking_up",       # rotulo da acao
    "putting_down",     # rotulo da acao
    "opt_spawn",
    "opt_chance",
    "opt_craft",
    "opt_capacity",
    "opt_light",
    "opt_threshold",
    "opt_reduction",
    "opt_duration",
    "opt_spill",
    "opt_weapons",
    "opt_running",
    "opt_corpses",
    "refuse",           # recusa curta ao tentar algo impossivel com o carrinho
)

LANGUAGES = {
    "EN": ("English", (
        "Wheelbarrow",
        "Put down wheelbarrow",
        "Load into",
        "Picking up",
        "Putting down",
        "Spawn in the world",
        "World spawn chance",
        "Allow crafting",
        "Capacity",
        "Light load limit",
        "Heavy item threshold",
        "Heavy item weight reduction",
        "Pick up / put down time",
        "Tip over when interrupted",
        "Block weapons while in use",
        "Block running while in use",
        "Allow corpses",
        "Not while carrying the wheelbarrow")),
    "PTBR": ("Português Brasileiro", (
        "Carrinho de mão",
        "Largar o carrinho de mão",
        "Carregar no",
        "Pegando",
        "Largando",
        "Aparecer no mundo",
        "Chance de aparecer",
        "Permitir fabricação",
        "Capacidade",
        "Limite de carga leve",
        "Limite de item pesado",
        "Redução de peso de item pesado",
        "Tempo para pegar e largar",
        "Tombar ao interromper",
        "Bloquear armas em uso",
        "Impedir corrida em uso",
        "Permitir corpos",
        "Não enquanto carrega o carrinho")),
    "PT": ("Português", (
        "Carrinho de mão",
        "Pousar o carrinho de mão",
        "Carregar no",
        "A pegar",
        "A pousar",
        "Aparecer no mundo",
        "Probabilidade de aparecer",
        "Permitir fabrico",
        "Capacidade",
        "Limite de carga leve",
        "Limite de item pesado",
        "Redução de peso de item pesado",
        "Tempo para pegar e pousar",
        "Tombar ao interromper",
        "Bloquear armas em uso",
        "Impedir corrida em uso",
        "Permitir cadáveres",
        "Não enquanto transporta o carrinho")),
    "ES": ("Español", (
        "Carretilla",
        "Dejar la carretilla",
        "Cargar en",
        "Recogiendo",
        "Dejando",
        "Aparecer en el mundo",
        "Probabilidad de aparición",
        "Permitir fabricación",
        "Capacidad",
        "Límite de carga ligera",
        "Umbral de objeto pesado",
        "Reducción de peso de objetos pesados",
        "Tiempo para coger y dejar",
        "Volcar al interrumpir",
        "Bloquear armas mientras se usa",
        "Impedir correr mientras se usa",
        "Permitir cadáveres",
        "No mientras llevas la carretilla")),
    "FR": ("Français", (
        "Brouette",
        "Poser la brouette",
        "Charger dans",
        "Ramassage",
        "Dépose",
        "Apparition dans le monde",
        "Chance d'apparition",
        "Autoriser la fabrication",
        "Capacité",
        "Limite de charge légère",
        "Seuil d'objet lourd",
        "Réduction de poids des objets lourds",
        "Temps pour prendre et poser",
        "Se renverser si interrompu",
        "Bloquer les armes pendant l'usage",
        "Empêcher de courir pendant l'usage",
        "Autoriser les cadavres",
        "Pas en portant la brouette")),
    "IT": ("Italiano", (
        "Carriola",
        "Posare la carriola",
        "Carica in",
        "Raccolta",
        "Deposito",
        "Comparsa nel mondo",
        "Probabilità di comparsa",
        "Consenti fabbricazione",
        "Capacità",
        "Limite di carico leggero",
        "Soglia oggetto pesante",
        "Riduzione peso oggetti pesanti",
        "Tempo per prendere e posare",
        "Ribalta se interrotta",
        "Blocca le armi durante l'uso",
        "Impedisci la corsa durante l'uso",
        "Consenti cadaveri",
        "Non mentre porti la carriola")),
    "DE": ("Deutsch", (
        "Schubkarre",
        "Schubkarre abstellen",
        "Laden in",
        "Aufheben",
        "Abstellen",
        "In der Welt erscheinen",
        "Erscheinungschance",
        "Herstellung erlauben",
        "Kapazität",
        "Grenze für leichte Ladung",
        "Schwellenwert für schwere Gegenstände",
        "Gewichtsreduktion schwerer Gegenstände",
        "Zeit zum Aufheben und Abstellen",
        "Bei Unterbrechung umkippen",
        "Waffen während der Nutzung sperren",
        "Rennen während der Nutzung sperren",
        "Leichen erlauben",
        "Nicht mit der Schubkarre in den Händen")),
    "NL": ("Nederlands", (
        "Kruiwagen",
        "Kruiwagen neerzetten",
        "Laden in",
        "Oppakken",
        "Neerzetten",
        "Verschijnen in de wereld",
        "Kans op verschijnen",
        "Vervaardigen toestaan",
        "Capaciteit",
        "Limiet lichte lading",
        "Drempel voor zware voorwerpen",
        "Gewichtsvermindering zware voorwerpen",
        "Tijd om op te pakken en neer te zetten",
        "Omkiepen bij onderbreking",
        "Wapens blokkeren tijdens gebruik",
        "Rennen blokkeren tijdens gebruik",
        "Lijken toestaan",
        "Niet met de kruiwagen in je handen")),
    "CA": ("Català", (
        "Carretó",
        "Deixar el carretó",
        "Carregar al",
        "Recollint",
        "Deixant",
        "Aparèixer al món",
        "Probabilitat d'aparició",
        "Permetre la fabricació",
        "Capacitat",
        "Límit de càrrega lleugera",
        "Llindar d'objecte pesant",
        "Reducció de pes d'objectes pesants",
        "Temps per agafar i deixar",
        "Bolcar si s'interromp",
        "Bloquejar armes mentre s'usa",
        "Impedir córrer mentre s'usa",
        "Permetre cadàvers",
        "No mentre portes el carretó")),
    "PL": ("Polski", (
        "Taczka",
        "Odstaw taczkę",
        "Załaduj do",
        "Podnoszenie",
        "Odstawianie",
        "Pojawianie się w świecie",
        "Szansa na pojawienie się",
        "Zezwól na wytwarzanie",
        "Pojemność",
        "Limit lekkiego ładunku",
        "Próg ciężkiego przedmiotu",
        "Redukcja wagi ciężkich przedmiotów",
        "Czas podnoszenia i odstawiania",
        "Przewróć przy przerwaniu",
        "Blokuj broń podczas używania",
        "Blokuj bieganie podczas używania",
        "Zezwól na zwłoki",
        "Nie z taczką w rękach")),
    "RU": ("Русский", (
        "Тачка",
        "Поставить тачку",
        "Загрузить в",
        "Поднимает",
        "Ставит",
        "Появление в мире",
        "Шанс появления",
        "Разрешить крафт",
        "Вместимость",
        "Предел лёгкого груза",
        "Порог тяжёлого предмета",
        "Снижение веса тяжёлых предметов",
        "Время подъёма и установки",
        "Опрокидывать при прерывании",
        "Блокировать оружие при использовании",
        "Блокировать бег при использовании",
        "Разрешить трупы",
        "Не с тачкой в руках")),
    "UA": ("Українська", (
        "Тачка",
        "Поставити тачку",
        "Завантажити в",
        "Піднімає",
        "Ставить",
        "Поява у світі",
        "Шанс появи",
        "Дозволити крафт",
        "Місткість",
        "Межа легкого вантажу",
        "Поріг важкого предмета",
        "Зменшення ваги важких предметів",
        "Час підняття та встановлення",
        "Перекидати при перериванні",
        "Блокувати зброю під час використання",
        "Блокувати біг під час використання",
        "Дозволити трупи",
        "Не з тачкою в руках")),
    "CS": ("Čeština", (
        "Kolečko",
        "Položit kolečko",
        "Naložit do",
        "Zvedání",
        "Pokládání",
        "Výskyt ve světě",
        "Šance na výskyt",
        "Povolit výrobu",
        "Kapacita",
        "Limit lehkého nákladu",
        "Práh těžkého předmětu",
        "Snížení váhy těžkých předmětů",
        "Čas zvednutí a položení",
        "Převrhnout při přerušení",
        "Blokovat zbraně při použití",
        "Blokovat běh při použití",
        "Povolit mrtvoly",
        "Ne s kolečkem v rukou")),
    "HU": ("Magyar", (
        "Talicska",
        "Talicska letétele",
        "Berakodás ide:",
        "Felvétel",
        "Letétel",
        "Megjelenés a világban",
        "Megjelenés esélye",
        "Barkácsolás engedélyezése",
        "Kapacitás",
        "Könnyű rakomány korlátja",
        "Nehéz tárgy küszöbe",
        "Nehéz tárgyak súlycsökkentése",
        "Felvétel és letétel ideje",
        "Felborul megszakításkor",
        "Fegyverek tiltása használat közben",
        "Futás tiltása használat közben",
        "Holttestek engedélyezése",
        "Nem a talicskával a kezedben")),
    "NO": ("Norsk", (
        "Trillebår",
        "Sett ned trillebåren",
        "Last inn i",
        "Plukker opp",
        "Setter ned",
        "Dukker opp i verden",
        "Sjanse for å dukke opp",
        "Tillat håndverk",
        "Kapasitet",
        "Grense for lett last",
        "Terskel for tunge gjenstander",
        "Vektreduksjon for tunge gjenstander",
        "Tid for å løfte og sette ned",
        "Velter ved avbrudd",
        "Blokker våpen under bruk",
        "Blokker løping under bruk",
        "Tillat lik",
        "Ikke med trillebåren i hendene")),
    "TR": ("Türkçe", (
        "El arabası",
        "El arabasını bırak",
        "Şuraya yükle:",
        "Alınıyor",
        "Bırakılıyor",
        "Dünyada belirme",
        "Belirme ihtimali",
        "Üretime izin ver",
        "Kapasite",
        "Hafif yük sınırı",
        "Ağır eşya eşiği",
        "Ağır eşya ağırlık azaltma",
        "Alma ve bırakma süresi",
        "Kesintide devrilir",
        "Kullanırken silahları engelle",
        "Kullanırken koşmayı engelle",
        "Cesetlere izin ver",
        "El arabası elindeyken olmaz")),
    "CN": ("简体中文", (
        "手推车",
        "放下手推车",
        "装入",
        "拾取中",
        "放下中",
        "在世界中生成",
        "生成几率",
        "允许制作",
        "容量",
        "轻物载重上限",
        "重物阈值",
        "重物减重",
        "拾取与放下耗时",
        "中断时翻倒",
        "使用时禁用武器",
        "使用时禁止奔跑",
        "允许装载尸体",
        "手推车在手时无法进行")),
    "CH": ("繁體中文", (
        "手推車",
        "放下手推車",
        "裝入",
        "拾取中",
        "放下中",
        "在世界中生成",
        "生成機率",
        "允許製作",
        "容量",
        "輕物載重上限",
        "重物門檻",
        "重物減重",
        "拾取與放下耗時",
        "中斷時翻倒",
        "使用時停用武器",
        "使用時禁止奔跑",
        "允許裝載屍體",
        "手推車在手時無法進行")),
    "JP": ("日本語", (
        "手押し車",
        "手押し車を置く",
        "積み込む:",
        "持ち上げ中",
        "下ろし中",
        "ワールドに出現",
        "出現確率",
        "クラフトを許可",
        "容量",
        "軽い荷物の上限",
        "重量物のしきい値",
        "重量物の重量軽減",
        "持ち上げ・下ろしの時間",
        "中断すると横倒しになる",
        "使用中は武器を禁止",
        "使用中は走行を禁止",
        "死体の積載を許可",
        "手押し車を持っている間はできません")),
    "KR": ("한국어", (
        "손수레",
        "손수레 내려놓기",
        "싣기:",
        "드는 중",
        "내려놓는 중",
        "월드에 생성",
        "생성 확률",
        "제작 허용",
        "용량",
        "가벼운 화물 한도",
        "무거운 물건 기준",
        "무거운 물건 무게 감소",
        "들고 내려놓는 시간",
        "중단 시 넘어짐",
        "사용 중 무기 차단",
        "사용 중 달리기 차단",
        "시체 허용",
        "손수레를 든 상태에서는 할 수 없습니다")),
    "TH": ("ไทย", (
        "รถเข็น",
        "วางรถเข็นลง",
        "บรรทุกลงใน",
        "กำลังยก",
        "กำลังวาง",
        "ปรากฏในโลก",
        "โอกาสปรากฏ",
        "อนุญาตให้ประดิษฐ์",
        "ความจุ",
        "ขีดจำกัดของบรรทุกเบา",
        "เกณฑ์ของหนัก",
        "ลดน้ำหนักของหนัก",
        "เวลายกและวาง",
        "ล้มคว่ำเมื่อถูกขัดจังหวะ",
        "ห้ามใช้อาวุธขณะใช้งาน",
        "ห้ามวิ่งขณะใช้งาน",
        "อนุญาตให้บรรทุกศพ",
        "ไม่ได้ขณะถือรถเข็น")),
    "VI": ("Tiếng Việt", (
        "Xe cút kít",
        "Đặt xe cút kít xuống",
        "Chất lên",
        "Đang nhấc",
        "Đang đặt xuống",
        "Xuất hiện trong thế giới",
        "Tỉ lệ xuất hiện",
        "Cho phép chế tạo",
        "Sức chứa",
        "Giới hạn tải nhẹ",
        "Ngưỡng vật nặng",
        "Giảm trọng lượng vật nặng",
        "Thời gian nhấc và đặt",
        "Đổ khi bị gián đoạn",
        "Chặn vũ khí khi đang dùng",
        "Chặn chạy khi đang dùng",
        "Cho phép chở xác",
        "Không thể khi đang cầm xe cút kít")),
    "AF": ("Afrikaans", (
        "Kruiwa",
        "Sit die kruiwa neer",
        "Laai in",
        "Tel op",
        "Sit neer",
        "Verskyn in die wêreld",
        "Kans om te verskyn",
        "Laat vervaardiging toe",
        "Kapasiteit",
        "Perk vir ligte vrag",
        "Drempel vir swaar voorwerpe",
        "Gewigsvermindering vir swaar voorwerpe",
        "Tyd om op te tel en neer te sit",
        "Val om wanneer onderbreek",
        "Blokkeer wapens tydens gebruik",
        "Blokkeer hardloop tydens gebruik",
        "Laat lyke toe",
        "Nie met die kruiwa in jou hande nie")),
}

# Tooltips: so em ingles, e o jogo cai para ca quando faltarem. Ver o cabecalho.
TOOLTIPS = {
    "Sandbox_MNWBEnableWorldSpawn_tooltip":
        "Wheelbarrows can be found lying around construction sites, warehouses "
        "and tool stores.<br>Turn off to make them craft-only.",
    "Sandbox_MNWBSpawnChance_tooltip":
        "Percent chance of a wheelbarrow spawning at an eligible spot.<br>Each "
        "spot is only ever rolled once.",
    "Sandbox_MNWBEnableCrafting_tooltip":
        "Enables the recipe to build a wheelbarrow from scratch.",
    "Sandbox_MNWBCapacity_tooltip":
        "How much the wheelbarrow can hold.<br>For reference: a generator is 40, "
        "a log is 9.<br>Load it while it sits on the ground; the game does not "
        "allow heavy items into a container you are holding.",
    "Sandbox_MNWBLightCapacity_tooltip":
        "A separate, much lower ceiling for items BELOW the heavy threshold.<br>Heavy "
        "cargo is repacked and takes a fifth of the room; light loot is not, and gets "
        "no weight relief either. This caps how much of it you can bring along.<br>Set "
        "to 0 to remove the light limit entirely.",
    "Sandbox_MNWBHeavyThreshold_tooltip":
        "Items at or above this weight count as heavy and get the weight "
        "reduction.<br>Anything lighter gets nothing at all; the wheelbarrow is "
        "deliberately useless for small loot.",
    "Sandbox_MNWBHeavyReduction_tooltip":
        "How much weight is taken off heavy items, in percent.<br>Light items "
        "are never reduced, no matter this setting.",
    "Sandbox_MNWBActionDuration_tooltip":
        "How long it takes to lift or set down the wheelbarrow.<br>Longer means "
        "cancelling it by accident is a real risk.",
    "Sandbox_MNWBSpillOnCancel_tooltip":
        "Cancelling the pick up or put down animation makes the wheelbarrow tip "
        "over, dumping its contents and itself on the ground.<br>Turn off for a "
        "forgiving game.",
    "Sandbox_MNWBBlockWeapons_tooltip":
        "The wheelbarrow takes both hands, so no weapon can be equipped while "
        "pushing it.",
    "Sandbox_MNWBBlockRunning_tooltip":
        "Pushing a loaded wheelbarrow is a walk, not a jog.<br>Turn off to keep "
        "running available at the reduced speed.",
    "Sandbox_MNWBAllowCorpses_tooltip":
        "Lets bodies be loaded into the wheelbarrow.<br>Turn off if hauling "
        "corpses makes clearing a house too easy for your taste.",
}

ITEM_TOOLTIP = (
    "Hauls very heavy loads: generators, logs, propane tanks.<br>Light items gain "
    "nothing from it, and only a little fits.<br>Occupies both hands, and you cannot "
    "run while pushing it.<br>Set it on the ground to load it."
)

RECIPE_TOOLTIP = (
    "Welds a wheelbarrow from sheet metal, pipe and a car tyre.<br>Needs a "
    "blowtorch, welding rods and a mask, so it is not an early-game build."
)

#: Tooltips em portugues.
#:
#: PORTUGUES E A EXCECAO A REGRA "tooltip so em ingles", e a razao e a mesma que
#: criou a regra. O risco de traduzir texto longo e que chave ERRADA nao cai para
#: nada -- fica errada para sempre -- e ninguem aqui saberia revisar um paragrafo
#: tecnico em tailandes. Em portugues sabemos. Onde a revisao existe, o motivo da
#: regra desaparece.
#:
#: O que nao estiver aqui cai para o ingles, que e o fallback do jogo.
TOOLTIPS_PT = {
    "PTBR": {
        "Tooltip_item_MNWheelbarrow":
            "Carrega peso muito alto: geradores, troncos, botijões.<br>Itens leves "
            "não ganham nada com ele, e cabe pouca tralha.<br>Ocupa as duas mãos, e "
            "não dá para correr enquanto o empurra.<br>Deixe no chão para carregar.",
        "Tooltip_craft_MNWBWheelbarrow":
            "Solda um carrinho de mão com chapa de metal, tubo e um pneu de "
            "carro.<br>Precisa de maçarico, varetas de solda e máscara, então não é "
            "coisa de começo de jogo.",
        "Sandbox_MNWBEnableWorldSpawn_tooltip":
            "Carrinhos aparecem largados em obras, galpões, garagens e lojas de "
            "ferramentas.<br>Desligue para que só existam por fabricação.",
        "Sandbox_MNWBSpawnChance_tooltip":
            "Chance, em porcento, de um carrinho aparecer num lugar elegível.<br>Cada "
            "lugar é sorteado uma única vez na vida do save.",
        "Sandbox_MNWBEnableCrafting_tooltip":
            "Libera a receita para construir um carrinho do zero.",
        "Sandbox_MNWBCapacity_tooltip":
            "Quanto o carrinho aguenta no total.<br>Para comparar: um gerador pesa "
            "40, um tronco 9.<br>Carregue com ele no chão; o jogo não aceita item "
            "pesado num compartimento que você está segurando.",
        "Sandbox_MNWBLightCapacity_tooltip":
            "Um teto separado, bem mais baixo, para itens ABAIXO do limite de peso "
            "pesado.<br>Carga pesada é reacondicionada e ocupa um quinto do espaço; "
            "tralha não é, e também não recebe alívio de peso. Isto limita quanta "
            "dela dá para levar junto.<br>Zero remove o limite de carga leve.",
        "Sandbox_MNWBHeavyThreshold_tooltip":
            "Item com este peso ou mais conta como pesado e recebe a redução.<br>Mais "
            "leve que isso não recebe nada: o carrinho é deliberadamente inútil para "
            "tralha pequena.",
        "Sandbox_MNWBHeavyReduction_tooltip":
            "Quanto peso sai dos itens pesados, em porcento.<br>Item leve nunca é "
            "reduzido, independente deste valor.",
        "Sandbox_MNWBActionDuration_tooltip":
            "Quanto tempo leva para erguer ou largar o carrinho.<br>Mais tempo "
            "significa que cancelar por acidente é um risco de verdade.",
        "Sandbox_MNWBSpillOnCancel_tooltip":
            "Cancelar a animação de pegar ou largar faz o carrinho tombar, "
            "derramando a carga e ele mesmo no chão.<br>Desligue para um jogo mais "
            "tolerante.",
        "Sandbox_MNWBBlockWeapons_tooltip":
            "O carrinho ocupa as duas mãos, então nenhuma arma pode ser equipada "
            "enquanto você o empurra.",
        "Sandbox_MNWBBlockRunning_tooltip":
            "Empurrar um carrinho carregado é caminhada, não corrida.<br>Desligue "
            "para poder correr na velocidade reduzida.",
        "Sandbox_MNWBAllowCorpses_tooltip":
            "Permite carregar corpos no carrinho.<br>Desligue se transportar "
            "cadáveres deixa limpar uma casa fácil demais para o seu gosto.",
    },
}

# PT de Portugal parte do PTBR: o texto tecnico e praticamente o mesmo, e o que
# difere de verdade sao os rotulos curtos, que ja estao na tabela LANGUAGES.
TOOLTIPS_PT["PT"] = dict(TOOLTIPS_PT["PTBR"])
TOOLTIPS_PT["PT"]["Tooltip_item_MNWheelbarrow"] = (
    "Transporta peso muito alto: geradores, troncos, botijas.<br>Itens leves não "
    "ganham nada com ele, e cabe pouca tralha.<br>Ocupa as duas mãos, e não dá para "
    "correr enquanto o empurra.<br>Deixe no chão para carregar."
)


def tooltip(language, key, fallback):
    """Tooltip do idioma, caindo para o ingles quando nao houver."""
    return TOOLTIPS_PT.get(language, {}).get(key, fallback)


OPTION_KEYS = (
    "Sandbox_MNWBEnableWorldSpawn", "Sandbox_MNWBSpawnChance",
    "Sandbox_MNWBEnableCrafting", "Sandbox_MNWBCapacity",
    "Sandbox_MNWBLightCapacity", "Sandbox_MNWBHeavyThreshold", "Sandbox_MNWBHeavyReduction",
    "Sandbox_MNWBActionDuration", "Sandbox_MNWBSpillOnCancel",
    "Sandbox_MNWBBlockWeapons", "Sandbox_MNWBBlockRunning",
    "Sandbox_MNWBAllowCorpses",
)


def write(path, payload):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with io.open(path, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(payload, ensure_ascii=False, indent=4) + "\n")


def main():
    for code, (name, values) in sorted(LANGUAGES.items()):
        if len(values) != len(FIELDS):
            raise SystemExit("%s tem %d strings, esperava %d"
                             % (code, len(values), len(FIELDS)))
        text = dict(zip(FIELDS, values))
        folder = os.path.join(OUT, code)

        write(os.path.join(folder, "language.json"),
              {"version": "1", "language_name": name})
        write(os.path.join(folder, "ItemName.json"),
              {"MNWheelbarrow.Wheelbarrow": text["wheelbarrow"]})
        write(os.path.join(folder, "ContextMenu.json"),
              {"ContextMenu_MNWB_PutDown": text["put_down"],
             "ContextMenu_MNWB_LoadInto": text["load_into"]})
        # NAO existe IGUI_ContainerTitle_ aqui de proposito. O titulo de um
        # container que vem de ITEM e o nome do item -- ISInventoryPage passa
        # item:getName() direto. A chave IGUI_ContainerTitle_<tipo> so vale para
        # container de objeto de mundo e de corpo, e o jogo base nao define nenhuma
        # para bolsa. Uma existiu aqui e nunca foi lida.
        write(os.path.join(folder, "IG_UI.json"), {
            "IGUI_MNWB_PickingUp": text["picking_up"],
            "IGUI_MNWB_PuttingDown": text["putting_down"],
            "IGUI_MNWB_Refuse": text["refuse"],
        })
        write(os.path.join(folder, "Tooltip.json"), {
            "Tooltip_item_MNWheelbarrow":
                tooltip(code, "Tooltip_item_MNWheelbarrow", ITEM_TOOLTIP),
            "Tooltip_craft_MNWBWheelbarrow":
                tooltip(code, "Tooltip_craft_MNWBWheelbarrow", RECIPE_TOOLTIP),
        })

        # A chave do nome de uma craftRecipe E o nome dela, sem prefixo -- ver
        # Recipes.json do jogo base, onde "Forge_Block_From_Chunk" e a chave.
        write(os.path.join(folder, "Recipes.json"),
              {"MakeWheelbarrow": text["wheelbarrow"]})

        sandbox = {"Sandbox_MNWheelbarrow": text["wheelbarrow"]}
        for key, label in zip(OPTION_KEYS, values[4:]):
            sandbox[key] = label
            sandbox[key + "_tooltip"] = tooltip(
                code, key + "_tooltip", TOOLTIPS[key + "_tooltip"])
        write(os.path.join(folder, "Sandbox.json"), sandbox)

        print("%-5s %-22s %d rotulos" % (code, name, len(values)))

    print("%d idiomas gerados" % len(LANGUAGES))


if __name__ == "__main__":
    main()
