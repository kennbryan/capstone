"""Live synthetic-account test. Run ONLY after approved migration/exposure.

No account creation, privileged key, migrations, .env changes or automatic retries.
Normal mode writes two synthetic check-ins on an initially empty test date.
--verify-only reads them after a backend restart; it does not write check-ins.
"""

import argparse
from datetime import date
from getpass import getpass
from uuid import UUID

import httpx

from app.config import load_settings

ACCOUNT_A = "admin.tester@example.invalid"
ACCOUNT_B = "tester.kedua@example.invalid"
BACKEND = "http://127.0.0.1:8001"
NOTE_A = "uji-checkin-sintetis-a"
NOTE_B = "uji-checkin-sintetis-b"


def require(condition, message):
    if not condition:
        raise SystemExit("DIHENTIKAN: " + message)


def login(client, base, key, email, label):
    response = client.post(
        base + "/auth/v1/token", params={"grant_type": "password"},
        headers={"apikey": key},
        json={"email": email, "password": getpass("Password " + label + ": ")},
    )
    print("Login " + label + ": HTTP", response.status_code)
    require(response.status_code == 200, "Login gagal; periksa password dan status akun.")
    session = response.json()
    require(session["user"]["email"].lower() == email, "Email sesi tidak sesuai.")
    UUID(session["user"]["id"])
    require(isinstance(session["access_token"], str) and bool(session["access_token"]),
            "Token sesi tidak lengkap.")
    return {"id": session["user"]["id"], "token": session["access_token"]}


def run(client, base, key, day, verify_only, *, restart_hint=True):
    # Preflight local rejection before asking for passwords or writing any data.
    params = {"from": day, "to": day}
    for headers in ({}, {"Authorization": "Bearer token-uji-tidak-valid"}):
        response = client.get(BACKEND + "/checkins", params=params, headers=headers)
        require(response.status_code == 401, "Check-in harus menolak token kosong/palsu dengan 401.")
    print("Penolakan token kosong/palsu: LULUS")

    a = login(client, base, key, ACCOUNT_A, "Admin Tester")
    b = login(client, base, key, ACCOUNT_B, "Tester Kedua")
    require(a["id"] != b["id"], "Kedua UUID harus berbeda.")

    def headers(session, direct=False):
        result = {"Authorization": "Bearer " + session["token"]}
        if direct:
            result.update({"apikey": key, "Accept-Profile": "chatbot"})
        return result

    def history(session):
        response = client.get(BACKEND + "/checkins", params=params, headers=headers(session))
        require(response.status_code == 200, "GET check-in gagal. Periksa migrasi, exposure, grants dan RLS.")
        rows = response.json()
        require(isinstance(rows, list), "Bentuk riwayat tidak sesuai.")
        return rows

    def save(session, mood, note=None):
        body = {"date": day, "mood": mood}
        if note is not None:
            body["note"] = note
        response = client.post(BACKEND + "/checkins", headers=headers(session), json=body)
        require(response.status_code == 200, "POST check-in gagal; jangan mengulang otomatis.")
        row = response.json()
        require(isinstance(row, dict) and row.get("date") == day and row.get("mood") == mood
                and row.get("note") == note, "Isi respons simpan tidak sesuai.")
        UUID(row["id"])
        return row

    # Read BOTH accounts first. Never overwrite an occupied test date on either one.
    before_a, before_b = history(a), history(b)
    if not verify_only:
        require(before_a == [] and before_b == [],
                "Tanggal uji sudah terisi. Pilih tanggal uji kosong lain; tidak ada check-in ditulis.")
        first_a = save(a, 4, NOTE_A)
        first_b = save(b, 5, NOTE_B)
        require(history(a) == [first_a] and history(b) == [first_b],
                "Baca ulang atau pemisahan riwayat tidak sesuai.")
        updated_a = save(a, 2)
        require(updated_a["id"] == first_a["id"], "Pembaruan tanggal sama harus mempertahankan ID.")
        require(history(a) == [updated_a] and history(b) == [first_b],
                "Pembaruan harus mengganti satu baris dan tidak memengaruhi akun lain.")
        print("Simpan, baca ulang, perbarui tanpa duplikat, hapus catatan: LULUS")

        for body in ({"date": day, "mood": 6}, {"date": day, "mood": 3, "user_id": b["id"]}):
            response = client.post(BACKEND + "/checkins", headers=headers(a), json=body)
            require(response.status_code == 422, "Mood tidak valid atau identitas dari body harus ditolak.")
        print("Validasi mood dan penolakan user_id dari body: LULUS")

    for session, target, mood, note, label in (
        (a, b, 2, None, "Admin Tester"), (b, a, 5, NOTE_B, "Tester Kedua"),
    ):
        own = history(session)
        require(len(own) == 1 and own[0].get("date") == day
                and own[0].get("mood") == mood and own[0].get("note") == note,
                "Data akhir tidak sesuai untuk " + label)
        # Direct Data API reads prove RLS independently of the backend's user_id filter.
        for owner, should_exist in ((session, True), (target, False)):
            response = client.get(
                base + "/rest/v1/checkins", headers=headers(session, direct=True),
                params={"select": "id,user_id,date,mood,note",
                        "user_id": "eq." + owner["id"], "date": "eq." + day},
            )
            require(response.status_code == 200, "Pemeriksaan langsung Data API gagal.")
            rows = response.json()
            if should_exist:
                require(isinstance(rows, list) and len(rows) == 1
                        and rows[0].get("user_id") == session["id"]
                        and rows[0].get("id") == own[0]["id"]
                        and rows[0].get("date") == day
                        and rows[0].get("mood") == mood and rows[0].get("note") == note,
                        "Data Supabase tidak sesuai dengan respons backend.")
            else:
                require(rows == [], "RLS masih memperlihatkan check-in akun lain.")

        if not verify_only:
            response = client.post(
                base + "/rest/v1/checkins",
                headers={**headers(session, direct=True), "Content-Profile": "chatbot",
                         "Prefer": "resolution=merge-duplicates,return=representation"},
                params={"on_conflict": "user_id,date"},
                json={"user_id": target["id"], "date": day, "mood": 1,
                      "note": "uji-penolakan-akses-sintetis"},
            )
            body = response.json()
            require(response.status_code == 403 and isinstance(body, dict) and body.get("code") == "42501",
                    "Penolakan penulisan ke akun lain belum terbukti. Hentikan pengujian.")
        print("Persistensi dan isolasi akses " + label + ": LULUS")

    # Recheck after attempted writes to confirm both final values remain intact.
    require(history(a)[0].get("mood") == 2 and history(a)[0].get("note") is None
            and history(b)[0].get("mood") == 5 and history(b)[0].get("note") == NOTE_B,
            "Nilai akhir berubah setelah pengujian akses.")
    print("SELESAI: pemeriksaan dalam mode ini LULUS.")
    if not verify_only and restart_hint:
        print("Berikutnya restart backend, lalu jalankan mode --verify-only dengan tanggal yang sama.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", required=True, help="Tanggal khusus uji YYYY-MM-DD yang kosong pada kedua akun")
    parser.add_argument("--verify-only", action="store_true", help="Baca ulang saja setelah restart backend")
    args = parser.parse_args()
    try:
        require(date.fromisoformat(args.date).isoformat() == args.date, "Format tanggal harus YYYY-MM-DD.")
        config = load_settings()
        with httpx.Client(timeout=20, follow_redirects=False, trust_env=False) as client:
            run(client, config.supabase_url.get_secret_value(),
                config.supabase_publishable_key.get_secret_value(), args.date, args.verify_only)
    except httpx.HTTPError:
        print("DIHENTIKAN: koneksi gagal/timeout; hasil penulisan mungkin belum diketahui.")
        print("Periksa riwayat sebelum mengulang. Jangan kirim token atau respons mentah.")
        raise SystemExit(1) from None
    except (ValueError, KeyError, TypeError, AttributeError, IndexError, RuntimeError):
        print("DIHENTIKAN: konfigurasi atau bentuk respons tidak sesuai. Jangan bagikan rahasia.")
        raise SystemExit(1) from None
    except (KeyboardInterrupt, EOFError):
        print("\nPengujian dihentikan. Jika sudah ada penulisan, periksa hasil sebelum mengulang.")
        raise SystemExit(1) from None


if __name__ == "__main__":
    main()
