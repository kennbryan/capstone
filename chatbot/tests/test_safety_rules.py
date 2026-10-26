import pytest

from app.safety import output_guard
from app.safety.lexicon import scan
from app.safety.triage import TriageOutput, combine


@pytest.mark.parametrize("text", [
    "aku pengen bunuh diri",
    "kepikiran bundir terus",
    "gue mau mati aja",
    "pengen mengakhiri hidup",
    "aku udah nyiapin tali",
    "semalem aku nyilet tangan lagi",
    "b*nuh diri kayaknya jalan keluar",
    "i want to kill myself",
    "pengen matiii",
])
def test_high_risk_detected(text):
    assert scan(text).level == "high"


@pytest.mark.parametrize("text", [
    "capek banget sama hidup",
    "rasanya pengen menghilang aja",
    "ga ada gunanya aku hidup",
    "mending aku ga pernah ada",
    "semua bakal lebih baik tanpa aku",
    "aku cuma jadi beban buat keluarga",
    "pengen tidur dan ga mau bangun lagi",
    "aku dipukul pacarku",
])
def test_moderate_risk_detected(text):
    assert scan(text).level == "moderate"


@pytest.mark.parametrize("text", [
    "tugasku numpuk banget, stres",
    "aku lagi sedih habis putus",
    "gimana cara tidur yang nyenyak?",
    "hp ku mati terus nih",
    "matikan lampu sebelum tidur ya",
    "aku capek habis praktikum",
])
def test_no_risk(text):
    assert scan(text).level == "none"


def _cls(level, subject="self"):
    return TriageOutput(risk_level=level, subject=subject, intent="emotional_support", rationale="-")


def test_combine_fail_safe_when_classifier_down():
    assert combine("high", "none", None)[0] == "high"


def test_classifier_cannot_drop_rule_high_below_moderate():
    assert combine("high", "none", _cls("low"))[0] == "moderate"


def test_classifier_can_raise_level():
    assert combine("none", "none", _cls("high"))[0] == "high"


def test_moderation_raises_level():
    assert combine("none", "high", _cls("low"))[0] == "high"


def test_general_question_about_suicide_not_crisis():
    assert combine("high", "none", _cls("none", subject="general"))[0] == "low"


@pytest.mark.parametrize("text,kind", [
    ("Sepertinya kamu mengalami depresi.", "diagnosis"),
    ("Kamu pasti bipolar.", "diagnosis"),
    ("Coba minum sertraline aja.", "medication"),
    ("Dosisnya 50 mg sehari.", "medication"),
    ("Apakah kamu сейчас sedang aman?", "foreign_script"),
])
def test_output_guard_flags(text, kind):
    assert kind in output_guard.check(text)


def test_output_guard_allows_safe_reply():
    assert output_guard.check("Kedengarannya berat ya. Mau coba napas lambat dua menit?") == []
