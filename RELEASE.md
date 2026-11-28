## 13.5.4

- Bags: Disenchant (or any spell waiting for an item) works from our bag window. 13.5.3 handed the item to the
  spell from add-on code, which the game blocks; the slot's secure button now does it with the game's own
  `/use bag slot`, set only for that click, so ordinary clicks still pick the item up. Not during combat.
