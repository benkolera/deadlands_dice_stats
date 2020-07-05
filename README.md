# DiceStats

This module empirically calculates the odds of rolling a result for exploding dice sets
in the game deadlands.

There are two main rolls: 
- Skill/Aptitude Rolls, where you roll something like 5d12 against a target number. In this roll
  only the highest roll is counted, and if the majority of the dice come up 1s then the roll
  fails no matter what the other dice are. It's the critical fail mechanic.
- Damage rolls, where the dice get added up and there is no failure

It outputs the stats to ./result.xlsx. An output is on [google sheets](https://docs.google.com/spreadsheets/d/1Y0_YeLu2Yy9NcZTqg5Tftj1P12yrWWTVDnyk8yt_iLk/edit?usp=sharing).

## Running

```
mix deps.get
mix run -e "DiceStats.run()"
```
