"""
Anonymize Pawlicious donation "responses.csv" before it goes into a public repo.

What this does:
- Drops direct identifiers entirely: email, phone number, personal Google Drive receipt link.
- Replaces the donor's real name with a stable pseudonymous ID (Donor_001, Donor_002, ...),
  generated from a *salted hash* of the original name+phone, so the same person always maps
  to the same Donor ID (useful for repeat-donor analysis) but the ID can't be reversed back
  to the name without the secret salt (which you keep private, NOT in the repo).
- Keeps everything needed for the dashboard: timestamp, donation amount.

Usage:
    python3 anonymize_responses.py responses.csv responses_anonymized.csv
"""

import csv
import hashlib
import sys

# Keep this salt PRIVATE. Do not commit it. Store it outside the repo
# (e.g. in a local .env file, password manager, or just in your own notes).
# Anyone with the salt + a guessed name/phone could re-identify a row, so
# treat it like a password.
SALT = "pawlicious-anonymization-salt"


def pseudonymize(name: str, phone: str) -> str:
    """Return a stable, non-reversible ID for a given name+phone pair."""
    key = f"{SALT}:{name.strip().lower()}:{phone.strip()}"
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
    return digest[:8]  # short hash, still ~4 billion combinations


def main(in_path: str, out_path: str):
    donor_id_map = {}  # hash -> sequential Donor_### label, so output reads cleanly
    next_id = 1

    with open(in_path, newline="", encoding="utf-8") as f_in, \
         open(out_path, "w", newline="", encoding="utf-8") as f_out:

        reader = csv.reader(f_in)
        writer = csv.writer(f_out)

        header = next(reader)
        # Original columns: row_id, col_a(timestamp), col_b(email), col_c(name),
        #                    col_d(amount), col_e(phone), col_f(receipt link)
        writer.writerow(["row_id", "timestamp", "donor_id", "amount_rm"])

        for row in reader:
            if len(row) < 6:
                continue
            row_id, timestamp, email, name, amount, phone = row[:6]

            # Row 1 in the original export is a duplicated pinyin header
            # ("Shi Jian Chuo Ji" = timestamp, "Xing Ming" = name, etc.),
            # not a real donor row -- skip it since we already wrote our own header.
            if name.strip() == "Xing Ming":
                continue

            digest = pseudonymize(name, phone)
            if digest not in donor_id_map:
                donor_id_map[digest] = f"Donor_{next_id:03d}"
                next_id += 1
            donor_label = donor_id_map[digest]

            writer.writerow([row_id, timestamp, donor_label, amount])

    print(f"Wrote {out_path}")
    print(f"{len(donor_id_map)} unique donors pseudonymized.")
    print("Remember: change SALT to a private random value, and never commit the salt "
          "or a name<->Donor_ID lookup table to the public repo.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 anonymize_responses.py <input.csv> <output.csv>")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
