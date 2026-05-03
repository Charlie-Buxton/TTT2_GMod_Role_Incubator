L = LANG.GetLanguageTableReference("en")

L[BIGFOOT.name] = "Bigfoot"
L["info_popup_" .. BIGFOOT.name] = [[You are Bigfoot (Innocent)!
If you are killed, you will instantly revive as a feral Bigfoot who cannot speak and cannot pick up weapons.]]
L["body_found_" .. BIGFOOT.abbr]  = "They were Bigfoot."
L["search_role_" .. BIGFOOT.abbr] = "This person was Bigfoot!"
L["target_" .. BIGFOOT.name]      = "Bigfoot"
L["ttt2_desc_" .. BIGFOOT.name]   = [[Bigfoot wins with the Innocents.
If Bigfoot is the last Innocent alive *after transforming*, the Traitors win.]]