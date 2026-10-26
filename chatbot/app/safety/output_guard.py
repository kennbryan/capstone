"""Pemeriksaan keluaran model sebelum dikirim ke pengguna.

Menangkap pelanggaran yang paling berisiko: diagnosis, saran obat atau dosis,
dan detail metode menyakiti diri. Pemeriksaan ini berbasis pola sehingga
cepat; sifatnya jaring pengaman, bukan jaminan."""

import re

_YOU = r"(kamu|anda|kau|lu|lo|loe|dirimu)"
_DISORDERS = (
    r"(depresi|depresif|bipolar|skizofrenia|ocd|ptsd|adhd|anxiety\s+disorder|"
    r"borderline|gangguan\s+kecemasan|gangguan\s+mental|gangguan\s+jiwa|psikosis|"
    r"gangguan\s+kepribadian|insomnia\s+kronis)"
)

_RULES: list[tuple[str, re.Pattern]] = [
    (
        "diagnosis",
        re.compile(
            rf"\b{_YOU}\s+(\w+\s+){{0,2}}(mengalami|menderita|terkena|kena|mengidap|punya|memiliki|sedang)\s+{_DISORDERS}",
            re.IGNORECASE,
        ),
    ),
    ("diagnosis", re.compile(rf"\b{_YOU}\s+(pasti|jelas|sepertinya|kemungkinan\s+besar)\s+{_DISORDERS}", re.IGNORECASE)),
    ("diagnosis", re.compile(r"\b(diagnosis|diagnosa)(mu|nya)?\s+(adalah|yaitu)\b", re.IGNORECASE)),
    (
        "medication",
        re.compile(
            r"\b(sertraline|fluoxetine|escitalopram|citalopram|paroxetine|alprazolam|xanax|diazepam|"
            r"valium|clonazepam|lorazepam|amitriptyline|amitriptilin|quetiapine|risperidone|"
            r"olanzapine|lithium|bupropion|zolpidem|melatonin|antidepresan\s+\w+|ssri)\b",
            re.IGNORECASE,
        ),
    ),
    ("medication", re.compile(r"\b\d+\s?(mg|miligram)\b", re.IGNORECASE)),
    (
        "method_detail",
        re.compile(
            r"\b(cara|metode|teknik)\s+(\w+\s+){0,2}(bunuh\s+diri|mengakhiri\s+hidup|menyilet|melukai\s+diri)",
            re.IGNORECASE,
        ),
    ),
    # model kadang menyelipkan kata dari bahasa lain (misalnya Kiril atau CJK)
    ("foreign_script", re.compile(r"[Ѐ-ӿ֐-ۿ฀-๿぀-ヿ一-鿿가-힯]")),
]


def check(text: str) -> list[str]:
    """Mengembalikan daftar jenis pelanggaran (kosong jika aman)."""
    found = []
    for name, pattern in _RULES:
        if pattern.search(text) and name not in found:
            found.append(name)
    return found
