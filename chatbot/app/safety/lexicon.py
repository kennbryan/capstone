"""Deteksi pola risiko berbasis aturan untuk bahasa Indonesia (formal dan informal).

Lapisan ini cepat, deterministik, dan tetap bekerja saat layanan LLM gagal.
Pola sengaja dibuat sensitif; classifier LLM yang menimbang konteks
(misalnya hiperbola atau pertanyaan tentang orang lain)."""

import re
from dataclasses import dataclass, field

LEVELS = ["none", "low", "moderate", "high"]


def level_max(*levels: str) -> str:
    return max(levels, key=LEVELS.index)


_ME = r"(aku|aq|saya|gue|gua|gw|ku)"
_WANT = r"(ingin|pengen|pengin|pingin|kepengen|mau|mo|niat|kepikiran|berencana|rencana)"
_NOT = r"(ga|gak|nggak|ngga|enggak|engga|tidak|tak|nda|ndak)"

# (kategori, level, pola)
_PATTERNS: list[tuple[str, str, str]] = [
    # Ide atau niat bunuh diri yang eksplisit
    ("suicide", "high", r"\bbunuh\s*diri\b"),
    ("suicide", "high", r"\bbundir\b"),
    ("suicide", "high", r"\bbu?nu?h\s*di?ri?\b"),  # versi disensor: b*nuh d*ri
    ("suicide", "high", r"\b(suicide|suicidal|kill\s+myself|end\s+my\s+life|kms|kys)\b"),
    ("suicide", "high", rf"\b{_WANT}\s+(\w+\s+){{0,2}}(mati|meninggal|mengakhiri\s+hidup|akhiri\s+hidup|udahan\s+(hidup|aja)|nyusul)\b"),
    ("suicide", "high", r"\b(mengakhiri|akhiri|akhirin|ngakhirin)\s+(hidup|nyawa)\w*"),
    ("suicide", "high", r"\b(gantung\s+diri|loncat\s+dari|lompat\s+dari|terjun\s+dari|nabrakin\s+diri|menabrakkan\s+diri)\b"),
    ("suicide", "high", r"\b(minum|nelen|menelan|telan)\s+(\w+\s+){0,2}(obat|pil|racun|baygon|pembersih)\s+(\w+\s+){0,2}(banyak|sekaligus|semua|sebotol|overdosis)\b"),
    ("suicide", "high", r"\b(overdosis|overdose|od\s+obat)\b"),
    ("suicide", "high", r"\b(udah|sudah|lagi)\s+(nyiapin|siapin|menyiapkan|beli|membeli|nyari)\s+(\w+\s+){0,2}(tali|racun|obat|silet|pisau)\b"),
    ("suicide", "high", r"\b(surat|pesan)\s+(wasiat|perpisahan|terakhir)\b"),
    ("suicide", "high", r"\bselamat\s+tinggal\s+(semua|semuanya|dunia)\b"),
    ("suicide", "high", r"\b(ini|malam\s+ini|hari\s+ini)\s+(yang\s+)?terakhir\s+(kalinya\s+)?" + _ME + r"?\s*(hidup|di\s+dunia)\b"),
    # Melukai diri
    ("self_harm", "high", r"\b(nyilet|menyilet|nyayat|menyayat|sayat|silet|ngiris|mengiris|melukai|lukain|nyakitin|menyakiti)\s+(\w+\s+){0,2}(diri|tangan|lengan|paha|nadi|badan)\b"),
    ("self_harm", "high", r"\b(self[\s-]?harm|cutting|selfharm)\b"),
    ("self_harm", "high", r"\b(memukul|mukul|benturin|membenturkan)\s+(\w+\s+){0,1}(kepala|diri)\s*(sendiri|ke\s+tembok)?"),
    # Membahayakan orang lain
    ("harm_others", "high", rf"\b{_WANT}\s+(\w+\s+){{0,2}}(bunuh|membunuh|nusuk|menusuk|mukulin|celakain|mencelakai)\s+(dia|mereka|orang|dosen|teman|temen|keluarga|ayah|ibu|pacar)\b"),
    # Ide pasif atau keputusasaan
    ("passive_ideation", "moderate", rf"\b{_WANT}\s+(\w+\s+){{0,1}}(hilang|menghilang|lenyap|tidur\s+selamanya)\b"),
    ("passive_ideation", "moderate", rf"\b(capek|cape|capai|lelah|muak)\s+(\w+\s+){{0,2}}(hidup|idup|jadi\s+manusia|bernapas|bernafas)\b"),
    ("passive_ideation", "moderate", rf"\b{_NOT}\s+(ada\s+)?(gunanya|artinya|alasan)\s+(\w+\s+){{0,2}}(hidup|idup|lanjut)\b"),
    ("passive_ideation", "moderate", rf"\b(lebih\s+baik|mending|mendingan)\s+{_ME}\s+{_NOT}\s+(ada|lahir|pernah\s+ada|usah\s+ada)\b"),
    ("passive_ideation", "moderate", rf"\b(lebih\s+baik|mending|mendingan)\s+{_ME}\s+(mati|hilang|pergi\s+selamanya)\b"),
    ("passive_ideation", "moderate", rf"\b(semua|semuanya|mereka|keluarga\w*)\s+(\w+\s+){{0,2}}lebih\s+(baik|bahagia|tenang)\s+tanpa\s+{_ME}\b"),
    ("passive_ideation", "moderate", rf"\b{_NOT}\s+(pengen|ingin|mau)\s+bangun\s+lagi\b"),
    ("passive_ideation", "moderate", rf"\b{_NOT}\s+(kuat|sanggup|tahan)\s+(\w+\s+){{0,1}}(hidup|idup)\b"),
    ("hopelessness", "moderate", r"\b(putus\s+asa|tidak\s+ada\s+harapan|ga\s+ada\s+harapan|gak\s+ada\s+harapan|nggak\s+ada\s+harapan|hopeless)\b"),
    ("hopelessness", "moderate", r"\bjadi\s+beban\s+(buat|bagi|untuk)\s+(semua|semuanya|keluarga|orang|mereka)\b"),
    # Kekerasan yang dialami
    ("abuse", "moderate", r"\b(dipukul|dipukulin|ditampar|dianiaya|disiksa|dilecehkan|pelecehan|diperkosa|kekerasan\s+seksual|kdrt|dikekang\s+dan\s+diancam)\b"),
]

_COMPILED = [(cat, lvl, re.compile(pat, re.IGNORECASE)) for cat, lvl, pat in _PATTERNS]

_LEET = str.maketrans({"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s"})


def normalize(text: str) -> str:
    text = text.lower().translate(_LEET)
    text = re.sub(r"[*_.\-]+(?=\w)", "", text)  # b*nuh, b.u.n.u.h
    text = re.sub(r"(\w)\1{2,}", r"\1", text)  # matiiii -> mati
    text = re.sub(r"[^\w\s]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


@dataclass
class RuleResult:
    level: str = "none"
    categories: list[str] = field(default_factory=list)


def scan(text: str) -> RuleResult:
    norm = normalize(text)
    result = RuleResult()
    for category, level, pattern in _COMPILED:
        if pattern.search(norm):
            result.level = level_max(result.level, level)
            if category not in result.categories:
                result.categories.append(category)
    return result
