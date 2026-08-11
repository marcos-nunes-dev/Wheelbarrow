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
    "picking_up",       # rotulo da acao
    "putting_down",     # rotulo da acao
    "opt_spawn",
    "opt_chance",
    "opt_craft",
    "opt_capacity",
    "opt_threshold",
    "opt_reduction",
    "opt_duration",
    "opt_spill",
    "opt_weapons",
    "opt_running",
    "opt_corpses",
)

LANGUAGES = {
    "EN": ("English", (
        "Wheelbarrow", "Put down wheelbarrow", "Picking up", "Putting down",
        "Spawn in the world", "World spawn chance", "Allow crafting", "Capacity",
        "Heavy item threshold", "Heavy item weight reduction",
        "Pick up / put down time", "Tip over when interrupted",
        "Block weapons while in use", "Block running while in use",
        "Allow corpses")),
    "PTBR": ("Português Brasileiro", (
        "Carrinho de mão", "Largar o carrinho de mão", "Pegando", "Largando",
        "Aparecer no mundo", "Chance de aparecer", "Permitir fabricação", "Capacidade",
        "Limite de item pesado", "Redução de peso de item pesado",
        "Tempo para pegar e largar", "Tombar ao interromper",
        "Bloquear armas em uso", "Impedir corrida em uso",
        "Permitir corpos")),
    "PT": ("Português", (
        "Carrinho de mão", "Pousar o carrinho de mão", "A pegar", "A pousar",
        "Aparecer no mundo", "Probabilidade de aparecer", "Permitir fabrico", "Capacidade",
        "Limite de item pesado", "Redução de peso de item pesado",
        "Tempo para pegar e pousar", "Tombar ao interromper",
        "Bloquear armas em uso", "Impedir corrida em uso",
        "Permitir cadáveres")),
    "ES": ("Español", (
        "Carretilla", "Dejar la carretilla", "Recogiendo", "Dejando",
        "Aparecer en el mundo", "Probabilidad de aparición", "Permitir fabricación", "Capacidad",
        "Umbral de objeto pesado", "Reducción de peso de objetos pesados",
        "Tiempo para coger y dejar", "Volcar al interrumpir",
        "Bloquear armas mientras se usa", "Impedir correr mientras se usa",
        "Permitir cadáveres")),
    "FR": ("Français", (
        "Brouette", "Poser la brouette", "Ramassage", "Dépose",
        "Apparition dans le monde", "Chance d'apparition", "Autoriser la fabrication", "Capacité",
        "Seuil d'objet lourd", "Réduction de poids des objets lourds",
        "Temps pour prendre et poser", "Se renverser si interrompu",
        "Bloquer les armes pendant l'usage", "Empêcher de courir pendant l'usage",
        "Autoriser les cadavres")),
    "IT": ("Italiano", (
        "Carriola", "Posare la carriola", "Raccolta", "Deposito",
        "Comparsa nel mondo", "Probabilità di comparsa", "Consenti fabbricazione", "Capacità",
        "Soglia oggetto pesante", "Riduzione peso oggetti pesanti",
        "Tempo per prendere e posare", "Ribalta se interrotta",
        "Blocca le armi durante l'uso", "Impedisci la corsa durante l'uso",
        "Consenti cadaveri")),
    "DE": ("Deutsch", (
        "Schubkarre", "Schubkarre abstellen", "Aufheben", "Abstellen",
        "In der Welt erscheinen", "Erscheinungschance", "Herstellung erlauben", "Kapazität",
        "Schwellenwert für schwere Gegenstände", "Gewichtsreduktion schwerer Gegenstände",
        "Zeit zum Aufheben und Abstellen", "Bei Unterbrechung umkippen",
        "Waffen während der Nutzung sperren", "Rennen während der Nutzung sperren",
        "Leichen erlauben")),
    "NL": ("Nederlands", (
        "Kruiwagen", "Kruiwagen neerzetten", "Oppakken", "Neerzetten",
        "Verschijnen in de wereld", "Kans op verschijnen", "Vervaardigen toestaan", "Capaciteit",
        "Drempel voor zware voorwerpen", "Gewichtsvermindering zware voorwerpen",
        "Tijd om op te pakken en neer te zetten", "Omkiepen bij onderbreking",
        "Wapens blokkeren tijdens gebruik", "Rennen blokkeren tijdens gebruik",
        "Lijken toestaan")),
    "CA": ("Català", (
        "Carretó", "Deixar el carretó", "Recollint", "Deixant",
        "Aparèixer al món", "Probabilitat d'aparició", "Permetre la fabricació", "Capacitat",
        "Llindar d'objecte pesant", "Reducció de pes d'objectes pesants",
        "Temps per agafar i deixar", "Bolcar si s'interromp",
        "Bloquejar armes mentre s'usa", "Impedir córrer mentre s'usa",
        "Permetre cadàvers")),
    "PL": ("Polski", (
        "Taczka", "Odstaw taczkę", "Podnoszenie", "Odstawianie",
        "Pojawianie się w świecie", "Szansa na pojawienie się", "Zezwól na wytwarzanie", "Pojemność",
        "Próg ciężkiego przedmiotu", "Redukcja wagi ciężkich przedmiotów",
        "Czas podnoszenia i odstawiania", "Przewróć przy przerwaniu",
        "Blokuj broń podczas używania", "Blokuj bieganie podczas używania",
        "Zezwól na zwłoki")),
    "RU": ("Русский", (
        "Тачка", "Поставить тачку", "Поднимает", "Ставит",
        "Появление в мире", "Шанс появления", "Разрешить крафт", "Вместимость",
        "Порог тяжёлого предмета", "Снижение веса тяжёлых предметов",
        "Время подъёма и установки", "Опрокидывать при прерывании",
        "Блокировать оружие при использовании", "Блокировать бег при использовании",
        "Разрешить трупы")),
    "UA": ("Українська", (
        "Тачка", "Поставити тачку", "Піднімає", "Ставить",
        "Поява у світі", "Шанс появи", "Дозволити крафт", "Місткість",
        "Поріг важкого предмета", "Зменшення ваги важких предметів",
        "Час підняття та встановлення", "Перекидати при перериванні",
        "Блокувати зброю під час використання", "Блокувати біг під час використання",
        "Дозволити трупи")),
    "CS": ("Čeština", (
        "Kolečko", "Položit kolečko", "Zvedání", "Pokládání",
        "Výskyt ve světě", "Šance na výskyt", "Povolit výrobu", "Kapacita",
        "Práh těžkého předmětu", "Snížení váhy těžkých předmětů",
        "Čas zvednutí a položení", "Převrhnout při přerušení",
        "Blokovat zbraně při použití", "Blokovat běh při použití",
        "Povolit mrtvoly")),
    "HU": ("Magyar", (
        "Talicska", "Talicska letétele", "Felvétel", "Letétel",
        "Megjelenés a világban", "Megjelenés esélye", "Barkácsolás engedélyezése", "Kapacitás",
        "Nehéz tárgy küszöbe", "Nehéz tárgyak súlycsökkentése",
        "Felvétel és letétel ideje", "Felborul megszakításkor",
        "Fegyverek tiltása használat közben", "Futás tiltása használat közben",
        "Holttestek engedélyezése")),
    "NO": ("Norsk", (
        "Trillebår", "Sett ned trillebåren", "Plukker opp", "Setter ned",
        "Dukker opp i verden", "Sjanse for å dukke opp", "Tillat håndverk", "Kapasitet",
        "Terskel for tunge gjenstander", "Vektreduksjon for tunge gjenstander",
        "Tid for å løfte og sette ned", "Velter ved avbrudd",
        "Blokker våpen under bruk", "Blokker løping under bruk",
        "Tillat lik")),
    "TR": ("Türkçe", (
        "El arabası", "El arabasını bırak", "Alınıyor", "Bırakılıyor",
        "Dünyada belirme", "Belirme ihtimali", "Üretime izin ver", "Kapasite",
        "Ağır eşya eşiği", "Ağır eşya ağırlık azaltma",
        "Alma ve bırakma süresi", "Kesintide devrilir",
        "Kullanırken silahları engelle", "Kullanırken koşmayı engelle",
        "Cesetlere izin ver")),
    "CN": ("简体中文", (
        "手推车", "放下手推车", "拾取中", "放下中",
        "在世界中生成", "生成几率", "允许制作", "容量",
        "重物阈值", "重物减重",
        "拾取与放下耗时", "中断时翻倒",
        "使用时禁用武器", "使用时禁止奔跑",
        "允许装载尸体")),
    "CH": ("繁體中文", (
        "手推車", "放下手推車", "拾取中", "放下中",
        "在世界中生成", "生成機率", "允許製作", "容量",
        "重物門檻", "重物減重",
        "拾取與放下耗時", "中斷時翻倒",
        "使用時停用武器", "使用時禁止奔跑",
        "允許裝載屍體")),
    "JP": ("日本語", (
        "手押し車", "手押し車を置く", "持ち上げ中", "下ろし中",
        "ワールドに出現", "出現確率", "クラフトを許可", "容量",
        "重量物のしきい値", "重量物の重量軽減",
        "持ち上げ・下ろしの時間", "中断すると横倒しになる",
        "使用中は武器を禁止", "使用中は走行を禁止",
        "死体の積載を許可")),
    "KR": ("한국어", (
        "손수레", "손수레 내려놓기", "드는 중", "내려놓는 중",
        "월드에 생성", "생성 확률", "제작 허용", "용량",
        "무거운 물건 기준", "무거운 물건 무게 감소",
        "들고 내려놓는 시간", "중단 시 넘어짐",
        "사용 중 무기 차단", "사용 중 달리기 차단",
        "시체 허용")),
    "TH": ("ไทย", (
        "รถเข็น", "วางรถเข็นลง", "กำลังยก", "กำลังวาง",
        "ปรากฏในโลก", "โอกาสปรากฏ", "อนุญาตให้ประดิษฐ์", "ความจุ",
        "เกณฑ์ของหนัก", "ลดน้ำหนักของหนัก",
        "เวลายกและวาง", "ล้มคว่ำเมื่อถูกขัดจังหวะ",
        "ห้ามใช้อาวุธขณะใช้งาน", "ห้ามวิ่งขณะใช้งาน",
        "อนุญาตให้บรรทุกศพ")),
    "VI": ("Tiếng Việt", (
        "Xe cút kít", "Đặt xe cút kít xuống", "Đang nhấc", "Đang đặt xuống",
        "Xuất hiện trong thế giới", "Tỉ lệ xuất hiện", "Cho phép chế tạo", "Sức chứa",
        "Ngưỡng vật nặng", "Giảm trọng lượng vật nặng",
        "Thời gian nhấc và đặt", "Đổ khi bị gián đoạn",
        "Chặn vũ khí khi đang dùng", "Chặn chạy khi đang dùng",
        "Cho phép chở xác")),
    "AF": ("Afrikaans", (
        "Kruiwa", "Sit die kruiwa neer", "Tel op", "Sit neer",
        "Verskyn in die wêreld", "Kans om te verskyn", "Laat vervaardiging toe", "Kapasiteit",
        "Drempel vir swaar voorwerpe", "Gewigsvermindering vir swaar voorwerpe",
        "Tyd om op te tel en neer te sit", "Val om wanneer onderbreek",
        "Blokkeer wapens tydens gebruik", "Blokkeer hardloop tydens gebruik",
        "Laat lyke toe")),
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
    "Hauls very heavy loads: generators, logs, propane tanks.<br>Light items "
    "gain nothing from it.<br>Occupies both hands, and you cannot run while "
    "pushing it.<br>Set it on the ground to load it."
)

OPTION_KEYS = (
    "Sandbox_MNWBEnableWorldSpawn", "Sandbox_MNWBSpawnChance",
    "Sandbox_MNWBEnableCrafting", "Sandbox_MNWBCapacity",
    "Sandbox_MNWBHeavyThreshold", "Sandbox_MNWBHeavyReduction",
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
              {"ContextMenu_MNWB_PutDown": text["put_down"]})
        write(os.path.join(folder, "IG_UI.json"), {
            "IGUI_ContainerTitle_wheelbarrow": text["wheelbarrow"],
            "IGUI_MNWB_PickingUp": text["picking_up"],
            "IGUI_MNWB_PuttingDown": text["putting_down"],
        })
        write(os.path.join(folder, "Tooltip.json"),
              {"Tooltip_item_MNWheelbarrow": ITEM_TOOLTIP})

        sandbox = {"Sandbox_MNWheelbarrow": text["wheelbarrow"]}
        for key, label in zip(OPTION_KEYS, values[4:]):
            sandbox[key] = label
            sandbox[key + "_tooltip"] = TOOLTIPS[key + "_tooltip"]
        write(os.path.join(folder, "Sandbox.json"), sandbox)

        print("%-5s %-22s %d rotulos" % (code, name, len(values)))

    print("%d idiomas gerados" % len(LANGUAGES))


if __name__ == "__main__":
    main()
