# M33kTriggers
Addon to add more triggers to [M33kAuras](https://github.com/m33shoq/M33kAuras) with the Midnight API by adding custom load/unload code in the Auras.  
An Addon for an Addon. 😜

## Triggers. Use in *Actions -> Custom functions -> Custom Load*
`M33kTriggers.ShowOnCdReady(aura_env, SpellID)`  
Shows the aura when a spell is off CD.

`M33kTriggers.ShowOnAllChargesReady(aura_env, SpellID)`  
Shows the aura when all the charges of a spell are available.

`M33kTriggers.ShowOnExecute(aura_env, SpellID, BelowHpPercent)`  
Shows the aura when an execute spell should be used (is off CD and target is below X% HP).

`M33kTriggers.ShowOnProc(aura_env, SpellID)`  
Shows the aura when a proc is available. Requires having the proc added to the CDM.

`M33kTriggers.ShowProcStacks(aura_env, SpellID)`  
Shows the stacks of a proc in a Text Aura when they are over 1. Requires having the proc added to the CDM Tracked Buffs.  

## Unload. Use in *Actions -> Custom functions -> Custom Unload*
`if aura_env.UnLoad then aura_env.UnLoad() end`

## Example
Example use to show an Aura when Mind Blast is off CD
![Example image](https://i.imgur.com/ISeLAAM.png)
