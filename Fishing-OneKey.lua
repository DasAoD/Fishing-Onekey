-- Fishing-OneKey
-- Legt Angeln-Werfen und Fang-Einholen auf eine einzige Taste.
--
-- Funktionsweise:
-- 1. Mit dem Chat-Befehl "/fok bind" ordnest du eine beliebige Taste der
--    Aktion "Angeln werfen / einholen" zu (Blizzards klassischer
--    Bindings.xml-Mechanismus fuer AddOn-Tastenbelegungen wird von diesem
--    Client nicht mehr unterstuetzt -- <Binding> wird als unbekanntes
--    XML-Element abgelehnt -- daher dieser eigene, minimale Weg).
-- 2. Ein Druck auf diese Taste "klickt" einen unsichtbaren Secure-Button,
--    der ueber SecureActionButtonTemplate "Angeln" castet -- genau die
--    Technik, mit der auch normale Aktionsleisten-Buttons Spells casten.
-- 3. Sobald der Angel-Channel (UNIT_SPELLCAST_CHANNEL_START) startet, wird
--    dieselbe physische Taste per SetOverrideBinding auf die eingebaute
--    Blizzard-Bindungsaktion "INTERACTTARGET" umgelegt (das ist exakt die
--    Aktion hinter der Interaktionstaste aus den Optionen).
-- 4. Endet der Channel (gefangen, abgebrochen, Zeit abgelaufen), wird die
--    Ueberschreibung wieder entfernt und die Taste wirft beim naechsten
--    Druck erneut die Angel aus.
--
-- Es wird an keiner Stelle eine geschuetzte Funktion direkt aus unsicherem
-- Code heraus aufgerufen: Der Angel-Cast laeuft ueber einen regulaeren
-- SecureActionButton (wie ein Aktionsleisten-Button), das Umlegen waehrend
-- des Channels ueber SetOverrideBinding auf eine bereits vorhandene,
-- Blizzard-eigene Bindungsaktion.

local ADDON_NAME = ...

FishingOneKeyDB = FishingOneKeyDB or {}

local FISHING_SPELL_ID = 131474
local CAST_BUTTON_NAME = "FishingOneKeyCastButton"
local CHAT_PREFIX = "|cff33ff99Fishing-OneKey|r: "

-- Lokalisierung der Chat-Ausgaben. enUS ist der Fallback fuer alle Clients
-- ohne eigenen Eintrag, deDE wird explizit ueberschrieben.
local L = {
    BIND_PROMPT = "Press the desired key now (ESC to cancel)...",
    BIND_CANCELLED = "Cancelled, previous assignment kept.",
    BIND_SET = "Key '%s' assigned.",
    COMBAT_LOCKDOWN = "Not possible in combat.",
    UNBOUND = "Key assignment removed.",
    STATUS = "/fok bind - assign a key | /fok unbind - remove assignment. Current: %s",
    STATUS_NONE = "none",
}

local locale = GetLocale()

if locale == "deDE" then
    L.BIND_PROMPT = "Druecke jetzt die gewuenschte Taste (ESC zum Abbrechen)..."
    L.BIND_CANCELLED = "Abgebrochen, alte Zuordnung bleibt bestehen."
    L.BIND_SET = "Taste '%s' zugewiesen."
    L.COMBAT_LOCKDOWN = "Geht nicht im Kampf."
    L.UNBOUND = "Tastenzuordnung entfernt."
    L.STATUS = "/fok bind - Taste zuweisen | /fok unbind - Zuordnung entfernen. Aktuell: %s"
    L.STATUS_NONE = "keine"
elseif locale == "frFR" then
    L.BIND_PROMPT = "Appuie maintenant sur la touche souhaitee (ESC pour annuler)..."
    L.BIND_CANCELLED = "Annule, l'attribution precedente est conservee."
    L.BIND_SET = "Touche '%s' attribuee."
    L.COMBAT_LOCKDOWN = "Impossible en combat."
    L.UNBOUND = "Attribution de touche supprimee."
    L.STATUS = "/fok bind - attribuer une touche | /fok unbind - supprimer l'attribution. Actuelle : %s"
    L.STATUS_NONE = "aucune"
elseif locale == "esES" or locale == "esMX" then
    L.BIND_PROMPT = "Pulsa ahora la tecla deseada (ESC para cancelar)..."
    L.BIND_CANCELLED = "Cancelado, se mantiene la asignacion anterior."
    L.BIND_SET = "Tecla '%s' asignada."
    L.COMBAT_LOCKDOWN = "No es posible en combate."
    L.UNBOUND = "Asignacion de tecla eliminada."
    L.STATUS = "/fok bind - asignar una tecla | /fok unbind - eliminar la asignacion. Actual: %s"
    L.STATUS_NONE = "ninguna"
elseif locale == "ptBR" then
    L.BIND_PROMPT = "Pressione agora a tecla desejada (ESC para cancelar)..."
    L.BIND_CANCELLED = "Cancelado, a atribuicao anterior foi mantida."
    L.BIND_SET = "Tecla '%s' atribuida."
    L.COMBAT_LOCKDOWN = "Nao e possivel em combate."
    L.UNBOUND = "Atribuicao de tecla removida."
    L.STATUS = "/fok bind - atribuir uma tecla | /fok unbind - remover atribuicao. Atual: %s"
    L.STATUS_NONE = "nenhuma"
elseif locale == "itIT" then
    L.BIND_PROMPT = "Premi ora il tasto desiderato (ESC per annullare)..."
    L.BIND_CANCELLED = "Annullato, l'assegnazione precedente e stata mantenuta."
    L.BIND_SET = "Tasto '%s' assegnato."
    L.COMBAT_LOCKDOWN = "Non possibile in combattimento."
    L.UNBOUND = "Assegnazione del tasto rimossa."
    L.STATUS = "/fok bind - assegna un tasto | /fok unbind - rimuovi l'assegnazione. Attuale: %s"
    L.STATUS_NONE = "nessuno"
elseif locale == "ruRU" then
    L.BIND_PROMPT = "Нажми нужную клавишу (ESC для отмены)..."
    L.BIND_CANCELLED = "Отменено, прежняя привязка сохранена."
    L.BIND_SET = "Клавиша '%s' назначена."
    L.COMBAT_LOCKDOWN = "Невозможно в бою."
    L.UNBOUND = "Привязка клавиши удалена."
    L.STATUS = "/fok bind - назначить клавишу | /fok unbind - удалить привязку. Текущая: %s"
    L.STATUS_NONE = "нет"
elseif locale == "koKR" then
    L.BIND_PROMPT = "원하는 키를 지금 누르세요 (ESC로 취소)..."
    L.BIND_CANCELLED = "취소됨, 이전 설정이 유지됩니다."
    L.BIND_SET = "'%s' 키가 지정되었습니다."
    L.COMBAT_LOCKDOWN = "전투 중에는 불가능합니다."
    L.UNBOUND = "키 지정이 제거되었습니다."
    L.STATUS = "/fok bind - 키 지정 | /fok unbind - 지정 제거. 현재: %s"
    L.STATUS_NONE = "없음"
elseif locale == "zhCN" then
    L.BIND_PROMPT = "请按下想要绑定的按键（按ESC取消）..."
    L.BIND_CANCELLED = "已取消，保留之前的绑定。"
    L.BIND_SET = "已绑定按键 '%s'。"
    L.COMBAT_LOCKDOWN = "战斗中无法执行。"
    L.UNBOUND = "已移除按键绑定。"
    L.STATUS = "/fok bind - 绑定按键 | /fok unbind - 移除绑定。当前：%s"
    L.STATUS_NONE = "无"
elseif locale == "zhTW" then
    L.BIND_PROMPT = "請按下想要綁定的按鍵（按ESC取消）..."
    L.BIND_CANCELLED = "已取消，保留之前的綁定。"
    L.BIND_SET = "已綁定按鍵 '%s'。"
    L.COMBAT_LOCKDOWN = "戰鬥中無法執行。"
    L.UNBOUND = "已移除按鍵綁定。"
    L.STATUS = "/fok bind - 綁定按鍵 | /fok unbind - 移除綁定。目前：%s"
    L.STATUS_NONE = "無"
end

-- Secure Button, der per Tastendruck "geklickt" wird und Angeln castet.
local castButton = CreateFrame("Button", CAST_BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
castButton:Hide()
castButton:RegisterForClicks("AnyUp", "AnyDown")
castButton:SetAttribute("type", "spell")
-- Ueber die Spell-ID statt des Namens ansprechen, damit das auch auf
-- nicht-englischen Clients (z. B. Deutsch: "Angeln") zuverlaessig castet.
castButton:SetAttribute("spell", FISHING_SPELL_ID)

local overrideFrame = CreateFrame("Frame", "FishingOneKeyOverrideFrame")

-- Ermittelt den lokalisierten Namen von "Angeln", unabhaengig davon,
-- welche Spell-API-Variante der Client gerade bereitstellt.
local function GetFishingSpellName()
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(FISHING_SPELL_ID)
    end
    return GetSpellInfo(FISHING_SPELL_ID)
end

local function IsFishingChannel()
    local channelName = UnitChannelInfo("player")
    if not channelName then
        return false
    end
    return channelName == GetFishingSpellName()
end

local function ActivateInteractOverride()
    if InCombatLockdown() then
        return
    end
    local key = FishingOneKeyDB.key
    if key then
        SetOverrideBinding(overrideFrame, true, key, "INTERACTTARGET")
    end
end

local function DeactivateInteractOverride()
    if InCombatLockdown() then
        return
    end
    ClearOverrideBindings(overrideFrame)
end

-- Legt die in FishingOneKeyDB.key gespeicherte Taste dauerhaft auf den
-- Cast-Button (uebersteht /reload und Login dank SaveBindings).
local function ApplyKeyBinding()
    if InCombatLockdown() then
        return
    end
    local key = FishingOneKeyDB.key
    if not key then
        return
    end
    SetBindingClick(key, CAST_BUTTON_NAME)
    SaveBindings(GetCurrentBindingSet())
end

local function ClearKeyBinding()
    if InCombatLockdown() then
        return
    end
    local key = FishingOneKeyDB.key
    if key then
        SetBinding(key)
        SaveBindings(GetCurrentBindingSet())
    end
end

-- Unsichtbarer Frame, der genau einen Tastendruck fuer "/fok bind" einfaengt.
local captureFrame = CreateFrame("Frame", nil, UIParent)
captureFrame:Hide()
captureFrame:EnableKeyboard(true)
captureFrame:SetPropagateKeyboardInput(false)
captureFrame:SetScript("OnKeyDown", function(self, key)
    if key == "UNKNOWN" then
        return
    end
    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
        or key == "LALT" or key == "RALT" then
        return
    end

    self:Hide()

    if key == "ESCAPE" then
        print(CHAT_PREFIX .. L.BIND_CANCELLED)
        return
    end

    if IsAltKeyDown() then
        key = "ALT-" .. key
    end
    if IsControlKeyDown() then
        key = "CTRL-" .. key
    end
    if IsShiftKeyDown() then
        key = "SHIFT-" .. key
    end

    ClearKeyBinding()
    FishingOneKeyDB.key = key
    ApplyKeyBinding()
    print(CHAT_PREFIX .. L.BIND_SET:format(key))
end)

local function NormalizeCmd(msg)
    msg = msg or ""
    msg = msg:match("^%s*(.-)%s*$") or ""
    return msg:lower()
end

SLASH_FISHINGONEKEY1 = "/fok"
SlashCmdList["FISHINGONEKEY"] = function(msg)
    local cmd = NormalizeCmd(msg)

    if cmd == "bind" then
        if InCombatLockdown() then
            print(CHAT_PREFIX .. L.COMBAT_LOCKDOWN)
            return
        end
        print(CHAT_PREFIX .. L.BIND_PROMPT)
        captureFrame:Show()
    elseif cmd == "unbind" then
        ClearKeyBinding()
        FishingOneKeyDB.key = nil
        print(CHAT_PREFIX .. L.UNBOUND)
    else
        local key = FishingOneKeyDB.key
        print(CHAT_PREFIX .. L.STATUS:format(key or L.STATUS_NONE))
    end
end

overrideFrame:RegisterEvent("PLAYER_LOGIN")
overrideFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
overrideFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
overrideFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

overrideFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        -- Sicherstellen, dass beim Login keine Override-Bindung haengen bleibt,
        -- und die gespeicherte Taste erneut auf den Cast-Button legen.
        DeactivateInteractOverride()
        ApplyKeyBinding()
        return
    end

    if unit ~= "player" then
        return
    end

    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if IsFishingChannel() then
            ActivateInteractOverride()
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        DeactivateInteractOverride()
    end
end)
