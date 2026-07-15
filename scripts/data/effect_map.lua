-----------------------------------
xi = xi or {}
xi.data = xi.data or {}
xi.data.effectMap = xi.data.effectMap or {}
-----------------------------------

-- Any active en-spell effect blocks reapplication of every other en-spell
-- (a higher tier still overrides a lower one).
local enspellEffects =
{
    xi.effect.ENAERO,
    xi.effect.ENBLIZZARD,
    xi.effect.ENFIRE,
    xi.effect.ENSTONE,
    xi.effect.ENTHUNDER,
    xi.effect.ENWATER,
    xi.effect.ENAERO_II,
    xi.effect.ENBLIZZARD_II,
    xi.effect.ENFIRE_II,
    xi.effect.ENSTONE_II,
    xi.effect.ENTHUNDER_II,
    xi.effect.ENWATER_II,
}

xi.data.effectMap.key =
{
    -- General Enhancements
    [xi.magic.spell.AQUAVEIL     ] = { 1, xi.effect.AQUAVEIL     },
    [xi.magic.spell.STONESKIN    ] = { 1, xi.effect.STONESKIN    },
    [xi.magic.spell.BLINK        ] = { 1, xi.effect.BLINK        },
    [xi.magic.spell.HASTE        ] = { 5, xi.effect.HASTE        },
    [xi.magic.spell.HASTEGA      ] = { 5, xi.effect.HASTE        },
    [xi.magic.spell.HASTE_II     ] = { 6, xi.effect.HASTE        },
    [xi.magic.spell.PHALANX      ] = { 1, xi.effect.PHALANX      },
    [xi.magic.spell.PHALANX_II   ] = { 2, xi.effect.PHALANX      },

    -- Protect / Protectra
    [xi.magic.spell.PROTECT      ] = { 1, xi.effect.PROTECT      },
    [xi.magic.spell.PROTECT_II   ] = { 2, xi.effect.PROTECT      },
    [xi.magic.spell.PROTECT_III  ] = { 3, xi.effect.PROTECT      },
    [xi.magic.spell.PROTECT_IV   ] = { 4, xi.effect.PROTECT      },
    [xi.magic.spell.PROTECT_V    ] = { 5, xi.effect.PROTECT      },
    [xi.magic.spell.PROTECTRA    ] = { 1, xi.effect.PROTECT      },
    [xi.magic.spell.PROTECTRA_II ] = { 2, xi.effect.PROTECT      },
    [xi.magic.spell.PROTECTRA_III] = { 3, xi.effect.PROTECT      },
    [xi.magic.spell.PROTECTRA_IV ] = { 4, xi.effect.PROTECT      },
    [xi.magic.spell.PROTECTRA_V  ] = { 5, xi.effect.PROTECT      },

    -- Shell / Shellra
    [xi.magic.spell.SHELL        ] = { 1, xi.effect.SHELL        },
    [xi.magic.spell.SHELL_II     ] = { 2, xi.effect.SHELL        },
    [xi.magic.spell.SHELL_III    ] = { 3, xi.effect.SHELL        },
    [xi.magic.spell.SHELL_IV     ] = { 4, xi.effect.SHELL        },
    [xi.magic.spell.SHELL_V      ] = { 5, xi.effect.SHELL        },
    [xi.magic.spell.SHELLRA      ] = { 1, xi.effect.SHELL        },
    [xi.magic.spell.SHELLRA_II   ] = { 2, xi.effect.SHELL        },
    [xi.magic.spell.SHELLRA_III  ] = { 3, xi.effect.SHELL        },
    [xi.magic.spell.SHELLRA_IV   ] = { 4, xi.effect.SHELL        },
    [xi.magic.spell.SHELLRA_V    ] = { 5, xi.effect.SHELL        },

    -- -Spikes
    [xi.magic.spell.BLAZE_SPIKES ] = { 1, xi.effect.BLAZE_SPIKES },
    [xi.magic.spell.DREAD_SPIKES ] = { 1, xi.effect.DREAD_SPIKES },
    [xi.magic.spell.ICE_SPIKES   ] = { 1, xi.effect.ICE_SPIKES   },
    [xi.magic.spell.SHOCK_SPIKES ] = { 1, xi.effect.SHOCK_SPIKES },

    -- Copy Image
    [xi.magic.spell.UTSUSEMI_ICHI] = { 1, xi.effect.COPY_IMAGE   },
    [xi.magic.spell.UTSUSEMI_NI  ] = { 1, xi.effect.COPY_IMAGE   },
    [xi.magic.spell.UTSUSEMI_SAN ] = { 1, xi.effect.COPY_IMAGE   },

    -- Regen
    [xi.magic.spell.REGEN        ] = { 1, xi.effect.REGEN        },
    [xi.magic.spell.REGEN_II     ] = { 2, xi.effect.REGEN        },
    [xi.magic.spell.REGEN_III    ] = { 3, xi.effect.REGEN        },
    [xi.magic.spell.REGEN_IV     ] = { 4, xi.effect.REGEN        },
    [xi.magic.spell.REGEN_V      ] = { 5, xi.effect.REGEN        },

    -- En-Spell
    [xi.magic.spell.ENAERO       ] = { 1, xi.effect.ENAERO,        enspellEffects },
    [xi.magic.spell.ENBLIZZARD   ] = { 1, xi.effect.ENBLIZZARD,    enspellEffects },
    [xi.magic.spell.ENFIRE       ] = { 1, xi.effect.ENFIRE,        enspellEffects },
    [xi.magic.spell.ENSTONE      ] = { 1, xi.effect.ENSTONE,       enspellEffects },
    [xi.magic.spell.ENTHUNDER    ] = { 1, xi.effect.ENTHUNDER,     enspellEffects },
    [xi.magic.spell.ENWATER      ] = { 1, xi.effect.ENWATER,       enspellEffects },
    [xi.magic.spell.ENAERO_II    ] = { 2, xi.effect.ENAERO_II,     enspellEffects },
    [xi.magic.spell.ENBLIZZARD_II] = { 2, xi.effect.ENBLIZZARD_II, enspellEffects },
    [xi.magic.spell.ENFIRE_II    ] = { 2, xi.effect.ENFIRE_II,     enspellEffects },
    [xi.magic.spell.ENSTONE_II   ] = { 2, xi.effect.ENSTONE_II,    enspellEffects },
    [xi.magic.spell.ENTHUNDER_II ] = { 2, xi.effect.ENTHUNDER_II,  enspellEffects },
    [xi.magic.spell.ENWATER_II   ] = { 2, xi.effect.ENWATER_II,    enspellEffects },
}
