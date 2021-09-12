# Fire Rate Increase Mult On Hit

Custom Attribute using Nosoop's [custom attributes framework](https://github.com/nosoop/SM-TFCustAttr). 
Each hit adds to a weapon's fire rate multiplier.
The more you hit someone, the faster your weapon becomes. It's customizable as you can change pretty much anything about it.
You can decide:
- If you want to have a decay, the amount of time before it starts & its amount. 
- The maximum amount of % & the amount you gain on hit.
- If there is an amount of damage you have to deal before you gain the %. If you don't hit it, the damage'll get stored until you have enough.

If someone has uber and you're hitting them, you won't gain anything but the decay won't start either.

## How to apply the attribute

`"speed increase mult on hit" 	"max=value amount=value damage_needed=value decay_time=value decay_amount=value"`

Shove it inside tf_custom_attributes.txt or anything else that supports custom attributes or in the Custom Attribuets section inside a custom weapon's cfg if you use Custom Weapons X.

```
- max           <- Maximum amount of fire rate multiplier ( 0.80 -> +80% of the original firerate ).
- amount        <- Additive amount of multiplier gained on hit.
- damage_needed <- Damage required before you get an amount of %.
- decay_time    <- Time before your speed starts to decay.
- decay_amount  <- The amount of % you lose per second.
```

Example stats: "max=0.80 amount=0.03 damage_needed=40.0 decay_time=5.0 decay_amount=0.05"
The max is 80%, you gain 3%, the damage you have to deal to gain the % is 40, the decay starts after you don't hit anyone for 5 seconds, you lose 5% per second ( more or less ).

## Dependencies

[Custom Attributes Framework](https://github.com/nosoop/SM-TFCustAttr)

[TF2 Attributes](https://github.com/nosoop/tf2attributes)

[TF2 Utils](https://github.com/nosoop/SM-TFUtils/)

You might need [this dependency as well](https://github.com/nosoop/stocksoup) if you want to compile it yourself.

## Other info

This plugin uses Nosoop's [Ninja](https://github.com/nosoop/NinjaBuild-SMPlugin) template. Easy to organize everything and build releases. I'd recommend to check it out.

#

Please, this is the first version of this plugin. If you find any issues, make sure to open an issue to let me know!
