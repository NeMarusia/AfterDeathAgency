from __future__ import annotations

from pathlib import Path

PATH = Path("main.gd")
REPLACEMENTS = {
    "var gained := reward * (1.0 + min(combo, 10) * 0.05 + departments[4].level * 0.06)":
        "var gained: float = reward * (1.0 + float(mini(combo, 10)) * 0.05 + float(int(departments[4].level)) * 0.06)",
    "var protection := departments[2].level * 0.08":
        "var protection: float = float(int(departments[2].level)) * 0.08",
    "var penalty := max(2.0, reward * (0.65 - min(protection, 0.45)))":
        "var penalty: float = maxf(2.0, reward * (0.65 - minf(protection, 0.45)))",
    "var loss := min(souls, float(rng.randi_range(3, 12)))":
        "var loss: float = minf(souls, float(rng.randi_range(3, 12)))",
    "var inspector_bonus := departments[2].level * 3":
        "var inspector_bonus: int = int(departments[2].level) * 3",
}

text = PATH.read_text(encoding="utf-8")
changed = False
for old, new in REPLACEMENTS.items():
    if old in text:
        text = text.replace(old, new, 1)
        changed = True
    elif new not in text:
        raise SystemExit(f"Expected expression not found: {old}")

if changed:
    PATH.write_text(text, encoding="utf-8")
    print("Repaired GDScript type inference errors.")
else:
    print("GDScript type repairs already applied.")
