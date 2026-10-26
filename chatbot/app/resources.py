"""Memuat data statis yang dikurasi: aktivitas, info bantuan, dan template krisis."""

from dataclasses import dataclass
from pathlib import Path

import yaml


@dataclass
class Resources:
    activities: dict[str, dict]
    help_resources: list[dict]
    crisis_templates: dict[str, str]
    crisis_version: int

    @property
    def crisis_help(self) -> list[dict]:
        return [r for r in self.help_resources if r.get("verified") and r.get("show_in_crisis")]

    def activity_catalog_text(self) -> str:
        return "\n".join(
            f"- {a['id']}: {a['title']} ({a['duration_min']} menit). Cocok untuk: {', '.join(a['tags'])}"
            for a in self.activities.values()
        )


def load_resources(data_dir: Path) -> Resources:
    def read(name):
        return yaml.safe_load((data_dir / name).read_text(encoding="utf-8"))

    activities = read("activities.yaml")
    crisis = read("crisis_templates.yaml")
    return Resources(
        activities={a["id"]: a for a in activities},
        help_resources=read("help_resources.yaml"),
        crisis_templates=crisis["templates"],
        crisis_version=crisis["version"],
    )
